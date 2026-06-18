#!/usr/bin/env bash
# =====================================================================
# For each benchmark this performs the full no-reboot flow via
# HW/reflash_verify.sh:  detach -> JTAG program -> attach -> evaluate.
# All privileged steps go through the passwordless helper, so no sudo
# password is prompted on a properly configured machine.
#
# Machine-specific settings (paths, helper) come from the repo-root
# `sourceme`; AE reviewers only edit that file, never this one.
#
# Usage:
#   ./run_all_board_tests.sh                  # all 5, skip ones already done
#   ./run_all_board_tests.sh st2_cifar100     # a subset
#   ./run_all_board_tests.sh --check          # validate inputs only
#   ./run_all_board_tests.sh --force          # re-run even if a log exists
# =====================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../sourceme"

REFLASH="$HW_IMPLE/reflash_verify.sh"
LOG_DIR="$ROOT_DIR/Log"

ALL_VARIANTS=(st4_cifar10 vgg11_cifar10 resnet18_cifar10 st2_cifar100 seg_land)

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
        --check)   CHECK_ONLY=1 ;;
        --force)   FORCE=1 ;;
        -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
        *)
            if [[ -n "${BIT[$a]:-}" ]]; then VARIANTS+=("$a")
            else echo "ERROR: unknown variant '$a' (valid: ${ALL_VARIANTS[*]})"; exit 1; fi
            ;;
    esac
done
[[ ${#VARIANTS[@]} -gt 0 ]] || VARIANTS=("${ALL_VARIANTS[@]}")

[[ -x "$REFLASH" ]] || { echo "ERROR: reflash script not found/executable: $REFLASH"; exit 1; }
command -v "$VIVADO" >/dev/null 2>&1 || { echo "ERROR: vivado not found ('$VIVADO'). Set VIVADO in sourceme."; exit 1; }

missing=0
for v in "${VARIANTS[@]}"; do
    if [[ ! -f "$OUTPUT_DIR/${BIT[$v]}" ]]; then
        echo "MISSING bitstream: $OUTPUT_DIR/${BIT[$v]}  (variant $v)"; missing=1
    fi
done
[[ $missing -eq 0 ]] || { echo "ERROR: generate the missing bitstreams first (AE_scripts/build_all_bitstreams.sh)."; exit 1; }

echo "=============================================================="
echo " FPL_AE on-board test (all benchmarks)"
echo " reflash   : $REFLASH"
echo " bitstreams: $OUTPUT_DIR"
echo " logs      : $LOG_DIR"
echo " helper    : ${FPL_AE_PRIV:-<repo fallback>}"
echo " variants  : ${VARIANTS[*]}"
echo "=============================================================="

if [[ $CHECK_ONLY -eq 1 ]]; then echo "Inputs OK."; exit 0; fi

mkdir -p "$LOG_DIR"

declare -A RESULT
declare -A PERF
t_all=$(date +%s)
for v in "${VARIANTS[@]}"; do
    mlog="$LOG_DIR/${v}.log"

    # Skip if a previous run already produced a valid [SUMMARY] result.
    if [[ $FORCE -eq 0 && -f "$mlog" ]] \
        && grep -qE '\[SUMMARY\]' "$mlog" 2>/dev/null; then
        summary="$(grep -E '\[SUMMARY\]' "$mlog" | tail -1 | sed -E 's/^\[SUMMARY\]\s*//')"
        perf="$(grep -E '\[BENCH\] throughput' "$mlog" 2>/dev/null | tail -1 | sed -E 's/^\[BENCH\]\s*//')"
        RESULT[$v]="SKIP $summary"
        PERF[$v]="${perf:-}"
        echo
        echo "[$(date -Iseconds)] SKIP  $v   (log exists: $mlog; use --force to re-run)"
        continue
    fi

    echo
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    echo "[$(date -Iseconds)] START on-board test: $v"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
    rc=0
    bash "$REFLASH" "$v" || rc=$?

    summary="$(grep -E '\[SUMMARY\]' "$mlog" 2>/dev/null | tail -1 | sed -E 's/^\[SUMMARY\]\s*//')"
    perf="$(grep -E '\[BENCH\] throughput' "$mlog" 2>/dev/null | tail -1 | sed -E 's/^\[BENCH\]\s*//')"
    if [[ $rc -eq 0 && -n "$summary" ]]; then
        RESULT[$v]="OK   $summary"
    else
        RESULT[$v]="FAILED (rc=$rc, see $LOG_DIR/${v}.log)"
    fi
    PERF[$v]="${perf:-}"
    echo "[$(date -Iseconds)] END   $v   ${RESULT[$v]}"
done

echo
echo "=============================================================="
echo " ON-BOARD TEST SUMMARY  (elapsed $(( ($(date +%s)-t_all)/60 )) min)"
echo "--------------------------------------------------------------"
for v in "${VARIANTS[@]}"; do
    printf " %-18s %s\n" "$v" "${RESULT[$v]}"
    [[ -n "${PERF[$v]}" ]] && printf " %-18s   %s\n" "" "${PERF[$v]}"
done
echo "=============================================================="
echo " per-test logs : $LOG_DIR/<variant>.log"

fail=0
for v in "${VARIANTS[@]}"; do
    case "${RESULT[$v]}" in OK*|SKIP*) ;; *) fail=1 ;; esac
done
exit $fail
