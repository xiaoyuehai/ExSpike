#!/usr/bin/env bash
# =====================================================================
# Usage:
#   ./run_ae_power.sh full           # ensure power.txt for each benchmark
#   ./run_ae_power.sh full --check   # list missing power.txt / SAIF only
#   ./run_ae_power.sh --help
#
# Full mode: for each benchmark under Power_estimation/Netlist/<bench>/,
# skip if power.txt already exists; otherwise run run_power_report.sh
# when the default SAIF file is present.
#
# Prerequisites per benchmark (not generated here):
#   - ExSpike_Top.edf
#   - <default_saif> (from GUI / gate-level xsim)
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../sourceme"

POWER_REPORT="$POWER/run_power_report.sh"
MODE=""
CHECK_ONLY=0

BENCHES=(
    VGG11_CIFAR10
    ResNet18_CIFAR10
    ST4_CIFAR10
    ST4_CIFAR10_G1
    ST2_CIFAR100
    SegNet
)

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

usage() {
    cat <<EOF
Usage: $0 full [--check]

Full mode: ensure Power_estimation/Netlist/<benchmark>/power.txt exists.
Existing power.txt files are left unchanged. Missing reports are generated
from the default SAIF in each benchmark directory via run_power_report.sh.

Benchmarks: ${BENCHES[*]}

Options:
  --check   Validate inputs only; do not run Vivado report_power
EOF
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        full)
            MODE="full"
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

[[ "$MODE" == "full" ]] || usage 1
[[ -x "$POWER_REPORT" ]] || { echo "ERROR: not found: $POWER_REPORT"; exit 1; }

missing_power=()
missing_saif=()
missing_edf=()
ready=()
skipped=()

for bench in "${BENCHES[@]}"; do
    net_dir="$POWER/Netlist/$bench"
    power_txt="$net_dir/power.txt"
    edf="$net_dir/ExSpike_Top.edf"
    saif_name="$(default_saif_name "$bench")"
    saif_path="$net_dir/$saif_name"

    if [[ -f "$power_txt" ]]; then
        skipped+=("$bench")
        continue
    fi

    if [[ ! -f "$edf" ]]; then
        missing_edf+=("$bench ($edf)")
        continue
    fi

    if [[ ! -f "$saif_path" ]]; then
        missing_saif+=("$bench ($saif_path)")
        continue
    fi

    ready+=("$bench")
done

echo "FPL_AE power reports: mode=full check_only=$CHECK_ONLY"
echo "------------------------------------------------------------"

if [[ ${#skipped[@]} -gt 0 ]]; then
    echo "Already have power.txt:"
    for bench in "${skipped[@]}"; do
        dyn="$(grep -m1 'Dynamic (W)' "$POWER/Netlist/$bench/power.txt" \
            | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
        echo "  OK  $bench${dyn:+  (Power ${dyn} W)}"
    done
fi

if [[ ${#missing_edf[@]} -gt 0 ]]; then
    echo "Missing EDIF:"
    printf '  %s\n' "${missing_edf[@]}"
fi

if [[ ${#missing_saif[@]} -gt 0 ]]; then
    echo "Missing SAIF (place GUI/gate SAIF, then re-run):"
    printf '  %s\n' "${missing_saif[@]}"
fi

if [[ ${#ready[@]} -eq 0 ]]; then
    if [[ ${#missing_saif[@]} -gt 0 || ${#missing_edf[@]} -gt 0 ]]; then
        echo "------------------------------------------------------------"
        echo "Nothing to generate."
        exit 1
    fi
    echo "------------------------------------------------------------"
    echo "All benchmarks already have power.txt."
    exit 0
fi

echo "Will generate power.txt:"
printf '  %s\n' "${ready[@]}"

if [[ "$CHECK_ONLY" -eq 1 ]]; then
    echo "------------------------------------------------------------"
    echo "Check only: ${#ready[@]} report(s) would be generated."
    exit 0
fi

echo "============================================================"
fail=0
for bench in "${ready[@]}"; do
    echo "============================================================"
    echo "Running: $POWER_REPORT $bench"
    if ! "$POWER_REPORT" "$bench"; then
        echo "ERROR: power report failed for $bench"
        fail=1
    fi
done

echo "============================================================"
echo "Summary:"
for bench in "${BENCHES[@]}"; do
    power_txt="$POWER/Netlist/$bench/power.txt"
    if [[ -f "$power_txt" ]]; then
        dyn="$(grep -m1 'Dynamic (W)' "$power_txt" \
            | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
        echo "  OK  $bench  $power_txt${dyn:+  (Power ${dyn} W)}"
    else
        echo "  --  $bench  (no power.txt)"
    fi
done

exit "$fail"
