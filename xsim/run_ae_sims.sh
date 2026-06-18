#!/usr/bin/env bash
# =====================================================================
# FPL_AE - run all 16 AE xsim jobs (4 benchmarks x 4 GROUP_NUMBER values)
#
# Usage:
#   ./run_ae_sims.sh              # sequential (recommended)
#   ./run_ae_sims.sh --parallel 2 # at most 2 concurrent sims
#   ./run_ae_sims.sh --dry-run
#   ./run_ae_sims.sh ST4_CIFAR10  # one benchmark, all groups
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/run_xsim.sh"

BENCHMARKS=(VGG11_CIFAR10 ResNet18_CIFAR10 ST4_CIFAR10 ST2_CIFAR100)
GROUP_NUMS=(1 2 4 8)
PARALLEL=1
DRY_RUN=0
FILTER_BENCH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --parallel)
            PARALLEL="${2:?--parallel requires a number}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--parallel N] [--dry-run] [benchmark]"
            exit 0
            ;;
        *)
            FILTER_BENCH="$1"
            shift
            ;;
    esac
done

if [[ -n "$FILTER_BENCH" ]]; then
    BENCHMARKS=("$FILTER_BENCH")
fi

run_one() {
    local bench="$1"
    local group="$2"
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "DRY-RUN: $RUNNER $bench $group"
        return 0
    fi
    echo "============================================================"
    "$RUNNER" "$bench" "$group"
}

jobs=()
for bench in "${BENCHMARKS[@]}"; do
    for group in "${GROUP_NUMS[@]}"; do
        jobs+=("$bench:$group")
    done
done

echo "FPL_AE xsim batch: ${#jobs[@]} runs, parallelism=$PARALLEL"
[[ "$DRY_RUN" -eq 1 ]] && echo "(dry-run)"

active=0
failed=0
for job in "${jobs[@]}"; do
    bench="${job%:*}"
    group="${job##*:}"

    if [[ "$PARALLEL" -le 1 ]]; then
        if ! run_one "$bench" "$group"; then
            failed=$((failed + 1))
        fi
    else
        run_one "$bench" "$group" &
        active=$((active + 1))
        if [[ "$active" -ge "$PARALLEL" ]]; then
            if ! wait -n; then
                failed=$((failed + 1))
            fi
            active=$((active - 1))
        fi
    fi
done

wait || failed=$((failed + 1))

echo "============================================================"
if [[ "$failed" -gt 0 ]]; then
    echo "DONE with $failed failure(s). Check xsim/logs/"
    exit 1
fi
echo "All ${#jobs[@]} simulations finished successfully."
