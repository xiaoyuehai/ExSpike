#!/bin/bash
# =====================================================================
# FPL_AE - build FPGA bitstreams from Synplify EDIF netlists.
# Post-synthesis (implementation-only) flow, non-project Vivado batch.
#
# Usage:
#   ./run_impl.sh                      # build ALL, sequential (recommended here)
#   ./run_impl.sh st4_cifar10          # build one variant
#   ./run_impl.sh all 1                # all, sequential
#   ./run_impl.sh all 5                # all, 5 in parallel (ONLY on big-RAM host!)
#
# Env:
#   VIVADO=/path/to/vivado   (default: vivado in PATH)
#   JOBS=N                   (per-Vivado place/route threads, default 2)
#
# Output:  HW/output/<bit>              (does NOT touch ../Bitstream/)
# Logs:    HW/logs/build_<variant>.log  and HW/logs/vivado_<variant>.log
#
# NOTE: xc7v2000t implementation is memory-heavy (~15-30 GB peak). On a
#       13 GB host run STRICTLY sequential (parallelism = 1).
# =====================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"      # HW build logs, kept separate from Evaluation Log/
TCL="$SCRIPT_DIR/scripts/impl_variant.tcl"
VIVADO="${VIVADO:-vivado}"
JOBS="${JOBS:-2}"

mkdir -p "$LOG_DIR" "$SCRIPT_DIR/output"

ALL="st4_cifar10 st2_cifar100 resnet18_cifar10 vgg11_cifar10 seg_land"

arg="${1:-all}"
par="${2:-1}"     # parallelism: 1 = sequential (default)

if [ "$arg" = "all" ]; then list="$ALL"; else list="$arg"; fi

run_one() {
    local key="$1"
    local log="$LOG_DIR/build_${key}.log"
    echo "[$(date -Iseconds)] START build $key  (log: $log)"
    "$VIVADO" -mode batch -nojournal \
        -log "$LOG_DIR/vivado_${key}.log" \
        -source "$TCL" -tclargs "$key" "$JOBS" > "$log" 2>&1
    local rc=$?
    echo "[$(date -Iseconds)] END   build $key  rc=$rc"
    return $rc
}

echo "Vivado     : $VIVADO"
echo "Variants   : $list"
echo "Parallelism: $par   (per-job jobs=$JOBS)"
echo "Output dir : $SCRIPT_DIR/output"
echo "------------------------------------------------------------"

if [ "$par" = "1" ]; then
    for k in $list; do run_one "$k"; done
else
    i=0
    for k in $list; do
        run_one "$k" &
        i=$((i+1))
        [ $((i % par)) -eq 0 ] && wait
    done
    wait
fi

echo "------------------------------------------------------------"
echo "All requested builds finished. Bitstreams in: $SCRIPT_DIR/output"
echo "Verify, then copy the ones you want into: $ROOT/Bitstream/"
