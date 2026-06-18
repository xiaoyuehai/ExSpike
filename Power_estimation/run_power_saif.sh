#!/usr/bin/env bash
# =====================================================================
# FPL_AE - xsim SAIF generation for power estimation
#
# Usage:
#   ./run_power_saif.sh <benchmark> [group] [saif_name] [options]
#
# Modes (default: --behav, matches power_provided behav/xsim flow):
#   --behav         RTL behavioral sim (fast, ~minutes)
#   --gate          Post-synth gate .vm netlist (slow, hours)
#
# Options:
#   --rebuild       Delete xsim.dir and force full xvlog+xelab
#   --sim-only      Skip compile; reuse existing snapshot and run xsim only
#   --compile-only  Compile/elab only; do not run xsim
#
# Examples:
#   ./run_power_saif.sh ResNet18_CIFAR10
#   ./run_power_saif.sh ResNet18_CIFAR10 2 --sim-only
#   ./run_power_saif.sh ResNet18_CIFAR10 2 --gate --rebuild
#
# Output SAIF: $POWER/Netlist/<benchmark>/<saif_name>
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../sourceme"

BENCH=""
GROUP=""
SAIF_NAME=""
MODE="behav"
REBUILD=0
SIM_ONLY=0
COMPILE_ONLY=0

usage() {
    cat <<EOF
Usage: $0 <benchmark> [group] [saif_name] [options]

Modes:
  --behav   RTL behavioral sim (default; matches power_provided behav/xsim)
  --gate    Post-synth gate .vm netlist (slow)

Options:
  --rebuild, --sim-only, --compile-only

Example:
  $0 ResNet18_CIFAR10 2
  $0 ResNet18_CIFAR10 2 --sim-only
EOF
    exit 1
}

default_saif_name() {
    case "$1" in
        ResNet18_CIFAR10) echo "exspike_apec2_resnet18.saif" ;;
        VGG11_CIFAR10)    echo "exspike_apec2_vgg11.saif" ;;
        ST4_CIFAR10)      echo "exspike_apec2_st4.saif" ;;
        ST2_CIFAR100)     echo "exspike_apec2_st2.saif" ;;
        *)                echo "exspike_apec2_${1,,}.saif" ;;
    esac
}

for arg in "$@"; do
    case "$arg" in
        --behav)         MODE="behav" ;;
        --gate)          MODE="gate" ;;
        --rebuild)       REBUILD=1 ;;
        --sim-only)      SIM_ONLY=1 ;;
        --compile-only)  COMPILE_ONLY=1 ;;
        --help|-h)       usage ;;
        *)
            if [[ -z "$BENCH" ]]; then
                BENCH="$arg"
            elif [[ -z "$GROUP" && "$arg" =~ ^[1248]$ ]]; then
                GROUP="$arg"
            elif [[ -z "$SAIF_NAME" ]]; then
                SAIF_NAME="$arg"
            else
                echo "ERROR: unexpected argument '$arg'"
                usage
            fi
            ;;
    esac
done

[[ -z "$BENCH" ]] && usage

GROUP="${GROUP:-2}"

if [[ -z "$SAIF_NAME" ]]; then
    SAIF_NAME="$(default_saif_name "$BENCH")"
fi

NET_DIR="$POWER/Netlist/$BENCH"
VM_NETLIST="$NET_DIR/ExSpike_Top.vm"
TB_DIR="$POWER/tb"
LOG_DIR="$POWER/logs"
SAIF_OUT="$NET_DIR/$SAIF_NAME"

if [[ "$MODE" == "behav" ]]; then
    RUN_DIR="$POWER/run_saif_behav/${BENCH}_g${GROUP}"
    RUN_TAG="${BENCH}_g${GROUP}_power_saif_behav"
    LOG_TAG="${BENCH}_g${GROUP}_saif_behav"
else
    RUN_DIR="$POWER/run_saif/${BENCH}_g${GROUP}"
    RUN_TAG="${BENCH}_g${GROUP}_power_saif"
    LOG_TAG="${BENCH}_g${GROUP}_saif"
fi

SNAPSHOT_DIR="$RUN_DIR/xsim.dir/${RUN_TAG}"

mkdir -p "$RUN_DIR" "$LOG_DIR" "$NET_DIR"
ln -sfn "$SIM_ROOT/$BENCH" "$RUN_DIR/simdata"

if [[ "$MODE" == "gate" && ! -f "$VM_NETLIST" ]]; then
    echo "ERROR: missing gate netlist: $VM_NETLIST"
    exit 1
fi

IP_CORES=(
    "${BENCH}_INST_MEM"
    "${BENCH}_INPUT_MAP"
    "${BENCH}_CODER_WEIGHT_MEM"
    "${BENCH}_BIAS_MEM"
    "${BENCH}_FC_WEIGHT_MEM"
    "MP_MEM"
    "FC_MP_MEM"
)

IP_FLIST="$RUN_DIR/ip.f"
: > "$IP_FLIST"

BLK_MEM_GEN="$XILINX_IP/ip/${BENCH}_INST_MEM/simulation/blk_mem_gen_v8_4.v"
if [[ ! -f "$BLK_MEM_GEN" ]]; then
    echo "ERROR: missing blk_mem_gen behavioral model: $BLK_MEM_GEN"
    exit 1
fi
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

SAIF_TCL="$RUN_DIR/saif_run.tcl"
cat > "$SAIF_TCL" <<EOF
run 300ns
open_saif "$SAIF_OUT"
set curr_xsim_wave_scope [current_scope]
current_scope /tb_top/inst_accelerator_top
log_saif [get_objects -r *]
current_scope \$curr_xsim_wave_scope
unset curr_xsim_wave_scope
run 300us
close_saif
EOF

BUILD_LOG="$LOG_DIR/${LOG_TAG}_build.log"
SIM_LOG="$LOG_DIR/${LOG_TAG}_sim.log"

cd "$RUN_DIR"

NEED_BUILD=1
if [[ -d "$SNAPSHOT_DIR" && "$REBUILD" -eq 0 ]]; then
    NEED_BUILD=0
fi

if [[ "$SIM_ONLY" -eq 1 && "$NEED_BUILD" -eq 1 ]]; then
    echo "ERROR: --sim-only requested but snapshot not found: $SNAPSHOT_DIR"
    echo "Run once without --sim-only (or with --rebuild) to build the snapshot."
    exit 1
fi

if [[ "$REBUILD" -eq 1 ]]; then
    echo "INFO: --rebuild: removing existing xsim snapshot"
    rm -rf xsim.dir .Xil xvlog.pb xelab.pb xsim.pb 2>/dev/null || true
    NEED_BUILD=1
fi

DEFINES=(
    -d "${BENCH}"
    -d "GROUP_NUMBER=${GROUP}"
    -d POWER_ESTIMATION
)

if [[ "$NEED_BUILD" -eq 1 ]]; then
    echo "[$(date -Iseconds)] BUILD SAIF ($MODE) $BENCH group=$GROUP"
    echo "  run dir : $RUN_DIR"
    echo "  saif    : $SAIF_OUT"
    echo "  xelab   : -debug typical (required for SAIF)"
    echo "------------------------------------------------------------"

    if [[ "$MODE" == "behav" ]]; then
        RTL_FLIST="$RUN_DIR/rtl.f"
        : > "$RTL_FLIST"
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*// ]] && continue
            [[ "$line" =~ ^tb/ ]] && continue
            echo "$RTL/$line" >> "$RTL_FLIST"
        done < "$XSIM_DIR/filelists/rtl.f"

        xvlog --incr -work work \
            -i "$POWER" \
            -i "$TB_DIR" \
            "${DEFINES[@]}" \
            -f "$RTL_FLIST" \
            -f "$IP_FLIST" \
            "$TB_DIR/tb_top.v" \
            "$TB_DIR/ddr_model_256bit.v" \
            > "$BUILD_LOG" 2>&1

        xelab -debug typical --timescale 1ns/1ps \
            tb_top -s "${RUN_TAG}" >> "$BUILD_LOG" 2>&1
    else
        DEFINES+=( -d POWER_GATE_NETLIST )
        echo "  netlist : $VM_NETLIST"

        xvlog --incr -work work \
            -i "$POWER" \
            -i "$TB_DIR" \
            "${DEFINES[@]}" \
            -f "$IP_FLIST" \
            "$VM_NETLIST" \
            "$TB_DIR/tb_top.v" \
            "$TB_DIR/ddr_model_256bit.v" \
            > "$BUILD_LOG" 2>&1

        NCPU="$(nproc 2>/dev/null || echo 4)"
        xelab -debug typical --timescale 1ns/1ps \
            -mt "$NCPU" -O0 \
            -L unisim -L unimacro \
            tb_top -s "${RUN_TAG}" >> "$BUILD_LOG" 2>&1
    fi
else
    echo "[$(date -Iseconds)] REUSE snapshot ($MODE) $RUN_TAG"
    echo "  run dir : $RUN_DIR"
    echo "  saif    : $SAIF_OUT"
    echo "  hint    : pass --rebuild to force full recompile"
    echo "------------------------------------------------------------"
fi

if [[ "$COMPILE_ONLY" -eq 1 ]]; then
    echo "Compile/elab OK (--compile-only). Log: $BUILD_LOG"
    exit 0
fi

echo "[$(date -Iseconds)] SIM SAIF ($MODE) $BENCH"
xsim "${RUN_TAG}" -tclbatch "$SAIF_TCL" > "$SIM_LOG" 2>&1

if [[ -f "$SAIF_OUT" ]]; then
    echo "OK: $SAIF_OUT ($(wc -c < "$SAIF_OUT") bytes)"
else
    echo "ERROR: SAIF not generated: $SAIF_OUT"
    echo "See logs: $BUILD_LOG $SIM_LOG"
    exit 1
fi
