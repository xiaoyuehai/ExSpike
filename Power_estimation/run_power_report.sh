#!/usr/bin/env bash
# =====================================================================
# FPL_AE - Vivado post-synthesis power report (EDIF + SAIF + clk.xdc)
#
# Usage:
#   ./run_power_report.sh <benchmark> [saif_name]
#
# Examples:
#   ./run_power_report.sh ResNet18_CIFAR10
#   ./run_power_report.sh ResNet18_CIFAR10 exspike_apec2_resnet18.saif
#
# Output: $POWER/Netlist/<benchmark>/power.txt
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../sourceme"

BENCH="${1:-}"
SAIF_NAME="${2:-}"

usage() {
    echo "Usage: $0 <benchmark> [saif_name]"
    exit 1
}

[[ -z "$BENCH" ]] && usage

default_saif_name() {
    case "$1" in
        ResNet18_CIFAR10) echo "exspike_apec2_resnet18.saif" ;;
        VGG11_CIFAR10)    echo "exspike_apec2_vgg11.saif" ;;
        ST4_CIFAR10)      echo "exspike_apec2_st4.saif" ;;
        ST4_CIFAR10_G1)   echo "exspike_apec1_st4.saif" ;;
        ST2_CIFAR100)     echo "exspike_apec2_st2.saif" ;;
        SegNet)           echo "exspike_apec2_segnet.saif" ;;
        *)                echo "exspike_apec2_${1,,}.saif" ;;
    esac
}

if [[ -z "$SAIF_NAME" ]]; then
    SAIF_NAME="$(default_saif_name "$BENCH")"
fi

NET_DIR="$POWER/Netlist/$BENCH"
SAIF_PATH="$NET_DIR/$SAIF_NAME"
OUT_PATH="$NET_DIR/power.txt"
LOG_DIR="$POWER/logs"
LOG_FILE="$LOG_DIR/${BENCH}_power_report.log"

mkdir -p "$LOG_DIR"

if [[ ! -f "$SAIF_PATH" ]]; then
    echo "ERROR: SAIF not found: $SAIF_PATH"
    echo "Place your SAIF under: $NET_DIR/<saif_name>"
    echo "Optional: generate locally with $SCRIPT_DIR/run_power_saif.sh $BENCH --gate"
    exit 1
fi

echo "[$(date -Iseconds)] POWER REPORT $BENCH"
echo "  saif : $SAIF_PATH"
echo "  out  : $OUT_PATH"
echo "------------------------------------------------------------"

"$VIVADO" -mode batch -notrace -nojournal -nolog \
    -source "$SCRIPT_DIR/scripts/report_power.tcl" \
    -tclargs "$BENCH" "$SAIF_PATH" "$OUT_PATH" \
    > "$LOG_FILE" 2>&1

if [[ -f "$OUT_PATH" ]]; then
    dyn="$(grep -m1 'Dynamic (W)' "$OUT_PATH" | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
    echo "OK: $OUT_PATH${dyn:+ (Power: ${dyn} W)}"
else
    echo "ERROR: power report not generated: $OUT_PATH"
    echo "See log: $LOG_FILE"
    exit 1
fi
