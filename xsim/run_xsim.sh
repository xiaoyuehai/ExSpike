#!/usr/bin/env bash
# =====================================================================
# FPL_AE - single xsim run for one benchmark + GROUP_NUMBER
#
# Usage:
#   ./run_xsim.sh <benchmark> <group> [--compile-only]
#
# Examples:
#   ./run_xsim.sh ST4_CIFAR10 2
#   ./run_xsim.sh VGG11_CIFAR10 8 --compile-only
#
# Requires: source ../sourceme (or run from repo with Vivado 2019.1 in PATH)
# Output:   $CYCLE_MODEL/<benchmark>/latency_report_group_<group>.txt
#           (ST2_CIFAR100 group 1/2 also writes figure8_group_<group>.txt)
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../sourceme"

BENCH="${1:-}"
GROUP="${2:-}"
COMPILE_ONLY=0
if [[ "${3:-}" == "--compile-only" ]]; then
    COMPILE_ONLY=1
fi

ALL_BENCHES="VGG11_CIFAR10 ResNet18_CIFAR10 ST4_CIFAR10 ST2_CIFAR100"
ALL_GROUPS="1 2 4 8"

usage() {
    echo "Usage: $0 <benchmark> <group> [--compile-only]"
    echo ""
    echo "  benchmark: $ALL_BENCHES"
    echo "  group:     $ALL_GROUPS"
    exit 1
}

[[ -z "$BENCH" || -z "$GROUP" ]] && usage

if ! echo "$ALL_BENCHES" | grep -qw "$BENCH"; then
    echo "ERROR: unknown benchmark '$BENCH'"
    usage
fi
if ! echo "$ALL_GROUPS" | grep -qw "$GROUP"; then
    echo "ERROR: unknown group '$GROUP' (expected 1, 2, 4, or 8)"
    usage
fi

RUN_TAG="${BENCH}_g${GROUP}"
RUN_DIR="$SCRIPT_DIR/run/${RUN_TAG}"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$RUN_DIR" "$LOG_DIR" "$CYCLE_MODEL/$BENCH"
ln -sfn "$SIM_ROOT/$BENCH" "$RUN_DIR/simdata"
ln -sfn "$CYCLE_MODEL/$BENCH" "$RUN_DIR/reports"

BUILD_LOG="$LOG_DIR/${RUN_TAG}_build.log"
SIM_LOG="$LOG_DIR/${RUN_TAG}_sim.log"

IP_CORES=(
    "${BENCH}_INST_MEM"
    "${BENCH}_INPUT_MAP"
    "${BENCH}_CODER_WEIGHT_MEM"
    "${BENCH}_BIAS_MEM"
    "${BENCH}_FC_WEIGHT_MEM"
    "MP_MEM"
    "FC_MP_MEM"
)

RTL_FLIST="$RUN_DIR/rtl.f"
IP_FLIST="$RUN_DIR/ip.f"
: > "$RTL_FLIST"
while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*// ]] && continue
    echo "$RTL/$line" >> "$RTL_FLIST"
done < "$SCRIPT_DIR/filelists/rtl.f"

BLK_MEM_GEN="$XILINX_IP/ip/${BENCH}_INST_MEM/simulation/blk_mem_gen_v8_4.v"
if [[ ! -f "$BLK_MEM_GEN" ]]; then
    echo "ERROR: missing blk_mem_gen behavioral model: $BLK_MEM_GEN"
    exit 1
fi

: > "$IP_FLIST"
echo "$BLK_MEM_GEN" >> "$IP_FLIST"
for core in "${IP_CORES[@]}"; do
    ip_dir="$XILINX_IP/ip/$core"
    sim_model="$ip_dir/sim/${core}.v"
    mif="$ip_dir/${core}.mif"
    if [[ ! -f "$sim_model" ]]; then
        echo "ERROR: missing IP behavioral sim model: $sim_model"
        exit 1
    fi
    echo "$sim_model" >> "$IP_FLIST"
    if [[ -f "$mif" ]]; then
        ln -sfn "$mif" "$RUN_DIR/${core}.mif"
    fi
done

cd "$RUN_DIR"
rm -rf xsim.dir .Xil xvlog.pb xelab.pb xsim.pb 2>/dev/null || true

DEFINES=(
    -d "${BENCH}"
    -d "GROUP_NUMBER=${GROUP}"
    -d LATENCY_REPORT
)

echo "[$(date -Iseconds)] BUILD $RUN_TAG"
echo "  run dir : $RUN_DIR"
echo "  report  : $CYCLE_MODEL/$BENCH/latency_report_group_${GROUP}.txt"
echo "------------------------------------------------------------"

xvlog --incr -work work \
    -i "$RTL" \
    "${DEFINES[@]}" \
    -f "$RTL_FLIST" \
    -f "$IP_FLIST" \
    > "$BUILD_LOG" 2>&1

xelab -debug typical --timescale 1ns/1ps tb_top -s "${RUN_TAG}_sim" >> "$BUILD_LOG" 2>&1

if [[ "$COMPILE_ONLY" -eq 1 ]]; then
    echo "Compile/elab OK (--compile-only). Log: $BUILD_LOG"
    exit 0
fi

echo "[$(date -Iseconds)] SIM   $RUN_TAG"
xsim "${RUN_TAG}_sim" -R > "$SIM_LOG" 2>&1

REPORT="$CYCLE_MODEL/$BENCH/latency_report_group_${GROUP}.txt"
if [[ -f "$REPORT" ]]; then
    echo "OK: $REPORT ($(wc -l < "$REPORT") lines)"
else
    echo "ERROR: expected report not found: $REPORT"
    echo "See logs: $BUILD_LOG $SIM_LOG"
    exit 1
fi
