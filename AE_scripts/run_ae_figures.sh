#!/usr/bin/env bash
# Usage:
#   ./run_ae_figures.sh fast          # use *_provided reference data
#   ./run_ae_figures.sh full          # use FPGA sim + cycle-model outputs
#   ./run_ae_figures.sh fast --check  # validate inputs only
#   ./run_ae_figures.sh --help
#
# Full mode: if simulation / cycle-model outputs are missing, this script
# automatically runs:
#   - xsim/run_ae_sims.sh           (16 FPGA simulations)
#   - cycle_model/run_cycle_models.sh (5 cycle-model jobs)
#
# Outputs (PNG):
#   Artifacts/Figure2_{fast|full}.png
#   Artifacts/Figure7_{fast|full}.png
#   Artifacts/Figure8_{fast|full}.png
#   Artifacts/Figure9.png             # same for both modes
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../sourceme"

AE_DIR="$CYCLE_MODEL/AE"
XSIM_BATCH="$XSIM_DIR/run_ae_sims.sh"
CYCLE_BATCH="$CYCLE_MODEL/run_cycle_models.sh"
MODE=""
CHECK_ONLY=0

usage() {
    cat <<EOF
Usage: $0 <fast|full> [--check]

Modes:
  fast   Plot from *_provided.json / *_provided.txt reference data
  full   Plot from cycle_model/results/*.json and FPGA latency/figure8 reports
         (auto-runs xsim + cycle_model if outputs are not ready)

Figure9 uses fixed reference numbers in both modes.

Outputs go to: $ARTIFACTS
EOF
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        fast|full)
            MODE="$1"
            shift
            ;;
        --check)
            CHECK_ONLY=1
            shift
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            echo "ERROR: unknown argument '$1'"
            usage 1
            ;;
    esac
done

[[ -n "$MODE" ]] || usage 1
mkdir -p "$ARTIFACTS"

"$PYTHON" - <<'PY' >/dev/null
import matplotlib
PY

check_missing() {
    (
        cd "$AE_DIR"
        "$PYTHON" -c "
import sys
from ae_paths import validate_inputs
missing = validate_inputs(sys.argv[1])
for path in missing:
    print(path)
sys.exit(1 if missing else 0)
" "$MODE"
    )
}

needs_cycle_model() {
    local f
    for f in \
        "$CYCLE_MODEL/results/Figure2_VGG11.json" \
        "$CYCLE_MODEL/results/VGG11_CIFAR10.json" \
        "$CYCLE_MODEL/results/ResNet18_CIFAR10.json" \
        "$CYCLE_MODEL/results/ST4_CIFAR10.json" \
        "$CYCLE_MODEL/results/ST2_CIFAR100.json"
    do
        [[ -f "$f" ]] || return 0
    done
    return 1
}

needs_xsim() {
    local bench group f
    for bench in VGG11_CIFAR10 ResNet18_CIFAR10 ST4_CIFAR10 ST2_CIFAR100; do
        for group in 1 2 4 8; do
            f="$CYCLE_MODEL/$bench/latency_report_group_${group}.txt"
            [[ -f "$f" ]] || return 0
        done
    done
    for group in 1 2; do
        f="$CYCLE_MODEL/ST2_CIFAR100/figure8_group_${group}.txt"
        [[ -f "$f" ]] || return 0
    done
    return 1
}

ensure_full_data() {
    local ran=0

    if needs_cycle_model; then
        echo "============================================================"
        echo "Full mode: cycle-model JSON outputs missing."
        echo "Running: $CYCLE_BATCH"
        echo "============================================================"
        [[ -x "$CYCLE_BATCH" ]] || { echo "ERROR: not found: $CYCLE_BATCH"; exit 1; }
        "$CYCLE_BATCH"
        ran=1
    fi

    if needs_xsim; then
        echo "============================================================"
        echo "Full mode: FPGA latency / figure8 reports missing."
        echo "Running: $XSIM_BATCH"
        echo "============================================================"
        [[ -x "$XSIM_BATCH" ]] || { echo "ERROR: not found: $XSIM_BATCH"; exit 1; }
        "$XSIM_BATCH"
        ran=1
    fi

    if [[ "$ran" -eq 1 ]]; then
        echo "Prerequisite generation finished. Re-checking full-mode inputs..."
    fi
}

missing="$(check_missing 2>/dev/null || true)"

if [[ -n "$missing" && "$MODE" == "full" && "$CHECK_ONLY" -eq 0 ]]; then
    ensure_full_data
    missing="$(check_missing 2>/dev/null || true)"
fi

if [[ -n "$missing" ]]; then
    echo "ERROR: missing input files for mode '$MODE':"
    echo "$missing" | sed 's/^/  /'
    echo ""
    if [[ "$MODE" == "fast" ]]; then
        echo "Fast mode expects *_provided.json and *_provided.txt under cycle_model/."
    else
        echo "Full mode still missing data after prerequisite runs."
        echo "Check logs under xsim/logs/ and cycle_model/logs/."
    fi
    exit 1
fi

if [[ "$CHECK_ONLY" -eq 1 ]]; then
    echo "Inputs OK for mode: $MODE"
    exit 0
fi

export AE_MODE="$MODE"

run_fig() {
    local script="$1"
    shift
    echo "[$(date -Iseconds)] $script $*"
    (
        cd "$AE_DIR"
        "$PYTHON" "$script" "$@"
    )
}

echo "FPL_AE figure generation: mode=$MODE"
echo "Output dir: $ARTIFACTS"
echo "------------------------------------------------------------"

run_fig figure2_fast.py --mode "$MODE" --output "$ARTIFACTS/Figure2_${MODE}.png"
run_fig figure7_fast.py --mode "$MODE" --output "$ARTIFACTS/Figure7_${MODE}.png"
run_fig figure8_fast.py --mode "$MODE" --output "$ARTIFACTS/Figure8_${MODE}.png"
run_fig figure9.py --output "$ARTIFACTS/Figure9.png"

echo "------------------------------------------------------------"
echo "Done. Generated:"
ls -1 "$ARTIFACTS"/Figure*.png 2>/dev/null || true
