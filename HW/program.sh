#!/usr/bin/env bash
# Vivado batch mode: program bitstream to FPGA (replaces GUI program)
#
# Usage:
#   ./program.sh <variant>
#   ./program.sh <path/to/custom.bit>
#
# Examples:
#   ./program.sh st4_cifar10
#   ./program.sh ../Bitstream/ExSpike_Top_ST4_CIFAR10.bit

set -euo pipefail

ARG="${1:-}"

if [ -z "$ARG" ]; then
    echo "Usage: $0 <variant|path/to.bit>"
    echo ""
    echo "Available variants:"
    grep -v '^#' "$(dirname "$0")/variants.conf" | grep -v '^[[:space:]]*$' | awk '{print "  " $1}'
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONF="$SCRIPT_DIR/variants.conf"
RUN_DIR="$AE_ROOT/Run"
LOG_DIR="$AE_ROOT/Log"

mkdir -p "$RUN_DIR" "$LOG_DIR"

if [ -f "$ARG" ]; then
    BIT_FILE="$(cd "$(dirname "$ARG")" && pwd)/$(basename "$ARG")"
    LOG_TAG="$(basename "$BIT_FILE" .bit)"
else
    BIT_NAME="$(awk -v v="$ARG" '$1==v {print $2; exit}' "$CONF")"
    if [ -z "${BIT_NAME:-}" ]; then
        echo "ERROR: unknown variant '$ARG'"
        exit 1
    fi
    BIT_FILE="$AE_ROOT/Bitstream/$BIT_NAME"
    LOG_TAG="$ARG"
fi

if [ ! -f "$BIT_FILE" ]; then
    echo "ERROR: bitstream not found: $BIT_FILE"
    exit 1
fi

PROG_LOG="$LOG_DIR/program_${LOG_TAG}.log"

echo "========================================"
echo "Bitstream: $BIT_FILE"
echo "Program log: $PROG_LOG"
echo "Started  : $(date -Iseconds)"
echo "========================================"

cd "$RUN_DIR"

vivado -mode batch -notrace \
    -source "$SCRIPT_DIR/scripts/program_device.tcl" \
    -tclargs "$BIT_FILE" \
    2>&1 | tee "$PROG_LOG"

echo "========================================"
echo "Finished : $(date -Iseconds)"
echo "Program log: $PROG_LOG"
echo "========================================"
