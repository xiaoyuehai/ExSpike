#!/usr/bin/env bash
# =====================================================================
#   ./build_all_bitstreams.sh                 # build missing 5, sequentially
#   ./build_all_bitstreams.sh vgg11_cifar10   # build a subset (if missing)
#   ./build_all_bitstreams.sh --check         # validate inputs only
#   ./build_all_bitstreams.sh --force         # rebuild even if .bit exists
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../sourceme"

ALL_VARIANTS=(st4_cifar10 vgg11_cifar10 resnet18_cifar10 st2_cifar100 seg_land)

declare -A EDF=(
    [st4_cifar10]=ExSpike_Top_ST4_CIFAR10.edf
    [vgg11_cifar10]=ExSpike_Top_VGG11_CIFAR10.edf
    [resnet18_cifar10]=ExSpike_Top_ResNet18_CIFAR10.edf
    [st2_cifar100]=ExSpike_Top_ST2_CIFAR100.edf
    [seg_land]=ExSpike_Top_SEG_NET.edf
)
declare -A BIT=(
    [st4_cifar10]=ExSpike_Top_ST4_CIFAR10.bit
    [vgg11_cifar10]=ExSpike_Top_VGG11_CIFAR10.bit
    [resnet18_cifar10]=ExSpike_Top_ResNet18_CIFAR10.bit
    [st2_cifar100]=ExSpike_Top_ST2_CIFAR100.bit
    [seg_land]=ExSpike_Top_SEG_NET.bit
)

CHECK_ONLY=0
FORCE=0
VARIANTS=()
for a in "$@"; do
    case "$a" in
        --check) CHECK_ONLY=1 ;;
        --force) FORCE=1 ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *)
            if [[ -n "${EDF[$a]:-}" ]]; then VARIANTS+=("$a")
            else echo "ERROR: unknown variant '$a' (valid: ${ALL_VARIANTS[*]})"; exit 1; fi
            ;;
    esac
done
[[ ${#VARIANTS[@]} -gt 0 ]] || VARIANTS=("${ALL_VARIANTS[@]}")

if ! command -v "$VIVADO" >/dev/null 2>&1; then
    echo "ERROR: vivado not found ('$VIVADO'). Set VIVADO in sourceme."; exit 1
fi
[[ -f "$IMPL_TCL" ]] || { echo "ERROR: impl tcl not found: $IMPL_TCL"; exit 1; }

missing=0
for v in "${VARIANTS[@]}"; do
    if [[ ! -f "$NETLIST_DIR/${EDF[$v]}" ]]; then
        echo "MISSING netlist: $NETLIST_DIR/${EDF[$v]}  (variant $v)"; missing=1
    fi
done
[[ $missing -eq 0 ]] || { echo "ERROR: place the missing .edf netlists, then re-run."; exit 1; }

echo "=============================================================="
echo " FPL_AE bitstream generation"
echo " vivado    : $VIVADO"
echo " part      : $FPGA_PART      impl jobs: $IMPL_JOBS"
echo " netlists  : $NETLIST_DIR"
echo " output    : $OUTPUT_DIR"
echo " logs      : $HW_LOG_DIR"
echo " variants  : ${VARIANTS[*]}"
echo "=============================================================="

if [[ $CHECK_ONLY -eq 1 ]]; then echo "Inputs OK."; exit 0; fi

mkdir -p "$OUTPUT_DIR" "$HW_LOG_DIR"

declare -A RESULT
t_all=$(date +%s)
for v in "${VARIANTS[@]}"; do
    if [[ $FORCE -eq 0 && -f "$OUTPUT_DIR/${BIT[$v]}" ]]; then
        echo "[$(date -Iseconds)] SKIP  $v   (exists: $OUTPUT_DIR/${BIT[$v]}; use --force to rebuild)"
        RESULT[$v]="SKIPPED (already built)"
        continue
    fi
    log="$HW_LOG_DIR/build_${v}.log"
    echo "[$(date -Iseconds)] START $v   (log: $log)"
    rc=0
    "$VIVADO" -mode batch -notrace -log "$HW_LOG_DIR/vivado_${v}.log" \
        -source "$IMPL_TCL" -tclargs "$v" "$IMPL_JOBS" > "$log" 2>&1 || rc=$?
    if [[ $rc -eq 0 && -f "$OUTPUT_DIR/${BIT[$v]}" ]]; then
        RESULT[$v]="OK"
    else
        RESULT[$v]="FAILED (rc=$rc, see $log)"
    fi
    echo "[$(date -Iseconds)] END   $v   ${RESULT[$v]}"
done

echo "=============================================================="
echo " SUMMARY  (elapsed $(( ($(date +%s)-t_all)/60 )) min)"
echo "--------------------------------------------------------------"
for v in "${VARIANTS[@]}"; do printf " %-18s %s\n" "$v" "${RESULT[$v]}"; done
echo "=============================================================="
echo " bitstreams in: $OUTPUT_DIR"
