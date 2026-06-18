#!/usr/bin/env bash
# =====================================================================
# Regenerates every figure and table from the shipped *_provided
# reference data only. No FPGA, no Vivado, no simulation, no rerun.
# Outputs overwrite the files under Artifacts/.
#
#   1. run_ae_figures.sh fast       (Figure*_fast.png from *_provided data)
#   2. run_ae_table2.sh  --provided (Artifacts/table2.csv)
#   3. run_ae_table1.sh  --provided (Artifacts/table1.csv)
#
# Usage:
#   ./run_all_artifact_fast.sh           # build all figures + tables
#   ./run_all_artifact_fast.sh --check   # validate provided inputs only
#   ./run_all_artifact_fast.sh --help
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../sourceme"

CHECK_ONLY=0
case "${1:-}" in
    --check)   CHECK_ONLY=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    "")        ;;
    *) echo "ERROR: unknown argument '$1'"; sed -n '2,20p' "$0"; exit 1 ;;
esac

STAGES=(
    "Figures (fast)|run_ae_figures.sh|fast"
    "Table 2 (provided)|run_ae_table2.sh|--provided"
    "Table 1 (provided)|run_ae_table1.sh|--provided"
)

run_stage() {
    local idx="$1" total="$2" label="$3" script="$4" args="$5"
    local path="$SCRIPT_DIR/$script"
    echo ""
    echo "=============================================================="
    echo " [$idx/$total] $label  ->  $script $args${CHECK_ONLY:+ --check}"
    echo "=============================================================="
    if [[ ! -x "$path" ]]; then
        echo "ERROR: $script not found or not executable at $path" >&2
        return 1
    fi
    local cmd=("$path")
    [[ -n "$args" ]] && cmd+=($args)
    [[ "$CHECK_ONLY" -eq 1 ]] && cmd+=(--check)
    "${cmd[@]}"
}

START_TS=$(date +%s)
total=${#STAGES[@]}
idx=0
for entry in "${STAGES[@]}"; do
    idx=$((idx + 1))
    IFS='|' read -r label script args <<< "$entry"
    if ! run_stage "$idx" "$total" "$label" "$script" "$args"; then
        echo ""
        echo "FAILED at stage $idx/$total ($label). Aborting." >&2
        exit 1
    fi
done

ELAPSED=$(( $(date +%s) - START_TS ))
echo ""
echo "=============================================================="
if [[ "$CHECK_ONLY" -eq 1 ]]; then
    echo " All $total stages validated OK (--check)."
else
    echo " All $total stages completed. Artifacts in: $ARTIFACTS"
fi
printf " Elapsed: %dh%02dm%02ds\n" $((ELAPSED/3600)) $(((ELAPSED%3600)/60)) $((ELAPSED%60))
echo "=============================================================="
