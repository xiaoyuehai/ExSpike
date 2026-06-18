#!/usr/bin/env bash
# Reflash a variant bitstream over JTAG and verify on board, no reboot.
# All privileged steps go through ae_hw_priv.sh (passwordless via sudoers).
#   ./reflash_verify.sh <variant_key> [path/to/custom.bit]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTDIR="$SCRIPT_DIR/output"
PROG_TCL="$SCRIPT_DIR/scripts/program_device.tcl"
# Prefer the root-owned, tamper-proof system helper (passwordless via sudoers);
# fall back to the in-repo copy on machines without it (will prompt for sudo).
PRIV="${FPL_AE_PRIV:-}"
if [[ -z "$PRIV" ]]; then
    if [[ -x /usr/local/sbin/fpl_ae_hw ]]; then PRIV=/usr/local/sbin/fpl_ae_hw
    else PRIV="$SCRIPT_DIR/ae_hw_priv.sh"; fi
fi
LAUNCH="$AE_ROOT/Evaluation/pcie_launch.sh"

declare -A BITMAP=(
    [st4_cifar10]="ExSpike_Top_ST4_CIFAR10.bit       cifar10_st"
    [vgg11_cifar10]="ExSpike_Top_VGG11_CIFAR10.bit     cifar10_vgg11"
    [resnet18_cifar10]="ExSpike_Top_ResNet18_CIFAR10.bit  cifar10_resnet18"
    [st2_cifar100]="ExSpike_Top_ST2_CIFAR100.bit      cifar100_st"
    [seg_land]="ExSpike_Top_SEG_NET.bit           land_seg"
)

KEY="${1:-}"
CUSTOM_BIT="${2:-}"
if [[ -z "$KEY" || -z "${BITMAP[$KEY]:-}" ]]; then
    echo "Usage: $0 <variant_key> [path/to/custom.bit]"
    echo "  variant_key: ${!BITMAP[*]}"
    exit 1
fi

read -r BITNAME LAUNCH_KEY <<<"${BITMAP[$KEY]}"
BIT_FILE="${CUSTOM_BIT:-$OUTDIR/$BITNAME}"
[[ -f "$BIT_FILE" ]] || { echo "ERROR: bitstream not found: $BIT_FILE"; exit 1; }
[[ -x "$PRIV" ]] || { echo "ERROR: privileged helper not found/executable: $PRIV"; exit 1; }

log() { echo "[$(date +%H:%M:%S)] $*"; }

DETACHED=0
cleanup() {
    local rc=$?
    if [[ $rc -ne 0 && $DETACHED -eq 1 ]] && ! lspci -Dn -d 10ee: | grep -q .; then
        log "ERROR path: re-attaching PCIe device ..."
        sudo "$PRIV" attach || true
    fi
}
trap cleanup EXIT

echo "=============================================================="
echo " FPL_AE reflash + verify  (no reboot)"
echo " variant   : $KEY     launch: $LAUNCH_KEY"
echo " bitstream : $BIT_FILE"
echo " started   : $(date -Iseconds)"
echo "=============================================================="

log "detach (rmmod + PCIe remove) ..."
sudo "$PRIV" detach
DETACHED=1
sleep 1

log "JTAG programming via Vivado batch (~1-2 min) ..."
JLOG="/tmp/fpl_ae_jtag_${KEY}.log"
if ! ( cd /tmp && vivado -mode batch -notrace -nojournal \
        -source "$PROG_TCL" -tclargs "$BIT_FILE" ) >"$JLOG" 2>&1; then
    echo "ERROR: JTAG programming failed. Tail of $JLOG:"; tail -n 40 "$JLOG"; exit 4
fi
log "programming done; settling ..."
sleep 3

log "attach (rescan + load driver + perms) ..."
sudo "$PRIV" attach
DETACHED=0

if ! lspci -Dn -d 10ee: | grep -q .; then
    echo "ERROR: device did not re-enumerate. Fallback: warm reboot (NOT poweroff), then: $LAUNCH $LAUNCH_KEY"
    exit 2
fi
ls /dev/xdma0_h2c_0 /dev/xdma0_c2h_0 >/dev/null 2>&1 \
    || { echo "ERROR: /dev/xdma0_* missing after attach."; exit 3; }
log "device + char nodes ready."

echo "=============================================================="
echo " reflash OK - launching evaluation: $LAUNCH $LAUNCH_KEY"
echo "=============================================================="
bash "$LAUNCH" "$LAUNCH_KEY"
