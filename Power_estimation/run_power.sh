#!/usr/bin/env bash
# =====================================================================
# FPL_AE - power report from provided SAIF (default) or full SAIF+report flow
#
# Usage:
#   ./run_power.sh <benchmark> [saif_name]           # report only (SAIF you provide)
#   ./run_power.sh <benchmark> [group] [saif_name] --generate [--gate|--behav] ...
#
# Examples:
#   ./run_power.sh ResNet18_CIFAR10
#   ./run_power.sh ResNet18_CIFAR10 exspike_apec2_resnet18.saif
#   ./run_power.sh ResNet18_CIFAR10 2 --generate --gate --rebuild
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../sourceme"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <benchmark> [saif_name]"
    echo "       $0 <benchmark> [group] [saif_name] --generate [run_power_saif options]"
    exit 1
fi

GENERATE=0
for arg in "$@"; do
    if [[ "$arg" == "--generate" ]]; then
        GENERATE=1
        break
    fi
done

BENCH="$1"
SAIF_NAME=""
for arg in "$@"; do
    case "$arg" in
        --*|ResNet18_CIFAR10|VGG11_CIFAR10|ST4_CIFAR10|ST2_CIFAR100|[1248]) ;;
        *)
            SAIF_NAME="$arg"
            ;;
    esac
done

if [[ "$GENERATE" -eq 1 ]]; then
    GEN_ARGS=()
    for arg in "$@"; do
        [[ "$arg" != "--generate" ]] && GEN_ARGS+=("$arg")
    done
    "$SCRIPT_DIR/run_power_saif.sh" "${GEN_ARGS[@]}"
    for arg in "$@"; do
        if [[ "$arg" == "--compile-only" ]]; then
            exit 0
        fi
    done
fi

"$SCRIPT_DIR/run_power_report.sh" "$BENCH" ${SAIF_NAME:+"$SAIF_NAME"}
