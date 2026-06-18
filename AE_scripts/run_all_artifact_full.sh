#!/usr/bin/env bash
# =====================================================================
# Runs every AE stage in dependency order:
#   1. run_ae_figures.sh full   (auto-runs xsim + cycle-model if needed)
#   2. run_ae_power.sh   full   (EDIF + SAIF -> power.txt per benchmark)
#   3. build_all_bitstreams.sh  (impl missing .bit for all 5 variants)
#   4. run_all_board_tests.sh   (program FPGA + evaluate -> Log/*.log)
#      ... or seed Log/*.log from Log/*_provided.log when no FPGA present.
#   5. run_ae_table2.sh         (assemble Artifacts/table2.csv)
#   6. run_ae_table1.sh         (post-synth util -> Artifacts/table1.csv)
#
# Usage:
#   ./run_all_artifact_full.sh           # auto-detect FPGA, run whole flow
#   ./run_all_artifact_full.sh --fpga    # force on-board testing
#   ./run_all_artifact_full.sh --no-fpga # skip board tests, use provided logs
#   ./run_all_artifact_full.sh --check   # validate every stage's inputs only
#   ./run_all_artifact_full.sh --help
#
# FPGA presence (board-test stage only): auto-detected from a Xilinx JTAG
# cable (USB 03fd) or a PCIe device (vendor 10ee); override with
# --fpga / --no-fpga.  Everything else (sim, power, bitstream, tables)
# runs identically and needs no FPGA.
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../sourceme"

CHECK_ONLY=0
FPGA_OVERRIDE=auto
for a in "$@"; do
    case "$a" in
        --check)   CHECK_ONLY=1 ;;
        --fpga)    FPGA_OVERRIDE=1 ;;
        --no-fpga) FPGA_OVERRIDE=0 ;;
        -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
        *) echo "ERROR: unknown argument '$a'"; sed -n '2,28p' "$0"; exit 1 ;;
    esac
done

detect_fpga() {
    if lsusb 2>/dev/null | grep -qiE '03fd:'; then return 0; fi
    if lspci -d 10ee: 2>/dev/null | grep -q .; then return 0; fi
    return 1
}

if [[ "$FPGA_OVERRIDE" == 1 ]]; then
    HAVE_FPGA=1
elif [[ "$FPGA_OVERRIDE" == 0 ]]; then
    HAVE_FPGA=0
elif detect_fpga; then
    HAVE_FPGA=1
else
    HAVE_FPGA=0
fi

BENCH_LOGS=(vgg11_cifar10 resnet18_cifar10 st4_cifar10 st2_cifar100 seg_land)

seed_provided_logs() {
    local seeded=0 missing=0 b prov gen
    for b in "${BENCH_LOGS[@]}"; do
        prov="$ROOT_DIR/Log/${b}_provided.log"
        gen="$ROOT_DIR/Log/${b}.log"
        if [[ ! -f "$prov" ]]; then
            echo "ERROR: no FPGA and no provided log: $prov" >&2
            missing=$((missing + 1))
            continue
        fi
        if [[ "$CHECK_ONLY" -eq 1 ]]; then
            echo "  -- $b  (would use $(basename "$prov"))"
        else
            cp -f "$prov" "$gen"
            echo "  OK  $b  <- $(basename "$prov")"
            seeded=$((seeded + 1))
        fi
    done
    [[ "$missing" -eq 0 ]]
}

run_board_stage() {
    echo ""
    echo "=============================================================="
    if [[ "$HAVE_FPGA" -eq 1 ]]; then
        echo " [4/$total] Board tests  ->  run_all_board_tests.sh${CHECK_ONLY:+ --check}  (FPGA detected)"
        echo "=============================================================="
        local cmd=("$SCRIPT_DIR/run_all_board_tests.sh")
        [[ "$CHECK_ONLY" -eq 1 ]] && cmd+=(--check)
        "${cmd[@]}"
    else
        echo " [4/$total] Board tests  ->  no FPGA: using Log/*_provided.log"
        echo "=============================================================="
        seed_provided_logs
    fi
}

# Stage table: "label|script|args" (args appended with --check in check mode)
STAGES=(
    "Figures (full)|run_ae_figures.sh|full"
    "Power reports|run_ae_power.sh|full"
    "Bitstreams|build_all_bitstreams.sh|"
    "Board tests|@board|"
    "Table 2|run_ae_table2.sh|"
    "Table 1|run_ae_table1.sh|"
)

run_stage() {
    local idx="$1" total="$2" label="$3" script="$4" args="$5"
    local path="$SCRIPT_DIR/$script"
    echo ""
    echo "=============================================================="
    echo " [$idx/$total] $label  ->  $script $args${CHECK_ONLY:+ --check}"
    echo "=============================================================="
    if [[ ! -x "$path" ]]; then
        echo "ERROR: $script not found or not executable at $path" >&2
        return 1
    fi
    local cmd=("$path")
    [[ -n "$args" ]] && cmd+=($args)
    [[ "$CHECK_ONLY" -eq 1 ]] && cmd+=(--check)
    "${cmd[@]}"
}

START_TS=$(date +%s)
total=${#STAGES[@]}
echo "FPL_AE full flow: FPGA=$([[ "$HAVE_FPGA" -eq 1 ]] && echo present || echo absent) check_only=$CHECK_ONLY"
idx=0
for entry in "${STAGES[@]}"; do
    idx=$((idx + 1))
    IFS='|' read -r label script args <<< "$entry"
    if [[ "$script" == "@board" ]]; then
        if ! run_board_stage; then
            echo ""
            echo "FAILED at stage $idx/$total ($label). Aborting." >&2
            exit 1
        fi
        continue
    fi
    if ! run_stage "$idx" "$total" "$label" "$script" "$args"; then
        echo ""
        echo "FAILED at stage $idx/$total ($label). Aborting." >&2
        exit 1
    fi
done

ELAPSED=$(( $(date +%s) - START_TS ))
echo ""
echo "=============================================================="
if [[ "$CHECK_ONLY" -eq 1 ]]; then
    echo " All $total stages validated OK (--check)."
else
    echo " All $total stages completed. Artifacts in: $ARTIFACTS"
fi
printf " Elapsed: %dh%02dm%02ds\n" $((ELAPSED/3600)) $(((ELAPSED%3600)/60)) $((ELAPSED%60))
echo "=============================================================="
