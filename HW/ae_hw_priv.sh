#!/usr/bin/env bash
set -euo pipefail

XDMA_TESTS="/home/yh/dma_ip_drivers/XDMA/linux-kernel/tests"
VENDOR="10ee"
NODES="/dev/xdma0_h2c_0 /dev/xdma0_c2h_0"

bdf() { lspci -Dn -d ${VENDOR}: | awk '{print $1; exit}'; }

set_perms() {
  for n in $NODES; do [ -e "$n" ] && chmod a+rw "$n"; done
  [ -e /dev/ttyUSB0 ] && chmod a+rw /dev/ttyUSB0 || true
}

case "${1:-}" in
  detach)
    if lsmod | grep -q '^xdma'; then rmmod xdma; fi
    B="$(bdf)"
    if [ -n "$B" ] && [ -e "/sys/bus/pci/devices/$B/remove" ]; then
      echo 1 > "/sys/bus/pci/devices/$B/remove"
    fi
    ;;
  attach)
    echo 1 > /sys/bus/pci/rescan
    sleep 2
    ( cd "$XDMA_TESTS" && ./load_driver.sh )
    set_perms
    ;;
  load)
    ( cd "$XDMA_TESTS" && ./load_driver.sh )
    set_perms
    ;;
  perms)
    set_perms
    ;;
  *)
    echo "usage: $0 {detach|attach|load|perms}"
    exit 1
    ;;
esac
