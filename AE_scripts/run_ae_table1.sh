#!/usr/bin/env bash
# =====================================================================
# Usage:
#   ./run_ae_table1.sh            # build Artifacts/table1.csv (Vivado util)
#   ./run_ae_table1.sh --provided # build from *_provided inputs (no Vivado)
#   ./run_ae_table1.sh --check    # validate inputs only, do not run Vivado
#   ./run_ae_table1.sh --force    # re-run Vivado even if util_hier.rpt exists
#   ./run_ae_table1.sh --help
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../sourceme"

UTIL_TCL="$POWER/scripts/report_util.tcl"
LOG_DIR="$POWER/logs"
OUT_CSV="$ARTIFACTS/table1.csv"
mkdir -p "$ARTIFACTS"

# Variant -> netlist dir name. Order matters: G1 first.
BENCH_G1="ST4_CIFAR10_G1"
BENCH_BASE="ST4_CIFAR10"

CHECK_ONLY=0
FORCE=0
USE_PROVIDED=0
for a in "$@"; do
    case "$a" in
        --check) CHECK_ONLY=1 ;;
        --force) FORCE=1 ;;
        --provided) USE_PROVIDED=1 ;;
        -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
        *) echo "ERROR: unknown argument '$a'"; sed -n '2,32p' "$0"; exit 1 ;;
    esac
done

[[ -f "$UTIL_TCL" ]] || { echo "ERROR: not found: $UTIL_TCL"; exit 1; }
mkdir -p "$LOG_DIR"

# Ensure a hierarchical utilization report exists for one benchmark.
ensure_util() {
    local bench="$1"
    local net_dir="$POWER/Netlist/$bench"
    local edf="$net_dir/ExSpike_Top.edf"
    local rpt="$net_dir/util_hier.rpt"
    local log="$LOG_DIR/${bench}_util_report.log"

    if [[ ! -f "$edf" ]]; then
        echo "ERROR: missing EDIF for $bench: $edf" >&2
        return 1
    fi
    if [[ -f "$rpt" && "$FORCE" -eq 0 ]]; then
        echo "  OK  $bench  (have util_hier.rpt)"
        return 0
    fi
    if [[ "$CHECK_ONLY" -eq 1 ]]; then
        echo "  -- $bench  (would generate util_hier.rpt)"
        return 0
    fi
    echo "  .. $bench  running report_utilization (post-synth) ..."
    if ! "$VIVADO" -mode batch -notrace -nojournal -nolog \
            -source "$UTIL_TCL" -tclargs "$bench" "$rpt" \
            > "$log" 2>&1; then
        echo "ERROR: utilization report failed for $bench (see $log)" >&2
        return 1
    fi
    [[ -f "$rpt" ]] || { echo "ERROR: report not produced: $rpt (see $log)" >&2; return 1; }
    echo "  OK  $bench  -> $rpt"
}

echo "FPL_AE table1: check_only=$CHECK_ONLY force=$FORCE provided=$USE_PROVIDED"
echo "------------------------------------------------------------"
if [[ "$USE_PROVIDED" -eq 1 ]]; then
    for b in "$BENCH_G1" "$BENCH_BASE"; do
        rpt="$POWER/Netlist/$b/util_hier_provided.rpt"
        if [[ -f "$rpt" ]]; then echo "  OK  $b  (have util_hier_provided.rpt)"
        else echo "ERROR: missing provided util: $rpt" >&2; exit 1; fi
    done
else
    ensure_util "$BENCH_G1"
    ensure_util "$BENCH_BASE"
fi

if [[ "$CHECK_ONLY" -eq 1 ]]; then
    echo "------------------------------------------------------------"
    echo "Check only: not parsing / writing table1.csv."
    exit 0
fi

echo "------------------------------------------------------------"
echo "Assembling $OUT_CSV ..."

export T1_BENCH_G1="$BENCH_G1"
export T1_BENCH_BASE="$BENCH_BASE"
export T1_OUT_CSV="$OUT_CSV"
export T1_USE_PROVIDED="$USE_PROVIDED"

"$PYTHON" - <<'PY'
import os
import re
import sys

POWER_NET = os.path.join(os.environ["POWER"], "Netlist")
BENCH_G1   = os.environ["T1_BENCH_G1"]
BENCH_BASE = os.environ["T1_BENCH_BASE"]
OUT_CSV    = os.environ["T1_OUT_CSV"]
USE_PROVIDED = os.environ.get("T1_USE_PROVIDED", "0") == "1"
UTIL_FNAME  = "util_hier_provided.rpt" if USE_PROVIDED else "util_hier.rpt"
POWER_FNAME = "power_provided.txt" if USE_PROVIDED else "power.txt"

# Core column -> list of netlist instance leaf names (summed).
# None => top cell ("(top)").
COLUMNS = [
    ("EPE Core",       ["U_WEIGHT_TOP", "U_READ_MEMBRANE_P", "U_READ_MP_BIAS"]),
    ("Attention Core", ["U_SPIKE_SIM"]),
    ("EAFC Core",      ["U_FC_CORE"]),
    ("Sparse Core",    ["U_SPARSE_PROCESSING"]),
    ("Total",          None),
]
NO_BRAM_COLS = {"Attention Core"}   # spec: Attention Core excludes BRAMs

errors = []


def parse_util(bench):
    """Return {instance_leaf: {luts,ffs,ramb36,ramb18}} plus '__TOP__'."""
    path = os.path.join(POWER_NET, bench, UTIL_FNAME)
    if not os.path.isfile(path):
        errors.append("missing util_hier.rpt: %s" % path)
        return {}
    out = {}
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if not line.startswith("|"):
                continue
            cols = [c.strip() for c in line.split("|")]
            # cols[1]=Instance cols[2]=Module cols[3]=Total LUTs ...
            #   cols[7]=FFs cols[8]=RAMB36 cols[9]=RAMB18 cols[10]=DSP48
            if len(cols) < 11:
                continue
            inst, mod = cols[1], cols[2]
            if inst.startswith("("):          # self-only row, skip
                continue
            try:
                rec = dict(
                    luts=int(cols[3].replace(",", "")),
                    ffs=int(cols[7].replace(",", "")),
                    ramb36=int(cols[8].replace(",", "")),
                    ramb18=int(cols[9].replace(",", "")),
                )
            except ValueError:
                continue
            if mod == "(top)" and "__TOP__" not in out:
                out["__TOP__"] = rec
            leaf = inst.split(".")[-1]         # 'genblk1.U_FC_CORE' -> 'U_FC_CORE'
            if leaf not in out:
                out[leaf] = rec
    return out


def parse_dynamic(bench):
    path = os.path.join(POWER_NET, bench, POWER_FNAME)
    pat = re.compile(r"Dynamic \(W\)\s*\|\s*([0-9.]+)")
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                m = pat.search(line)
                if m:
                    return float(m.group(1))
    except OSError:
        pass
    errors.append("could not read Dynamic (W) from %s" % path)
    return None


def fmt_bram(rec):
    v = rec["ramb36"] + 0.5 * rec["ramb18"]
    return str(int(v)) if v == int(v) else ("%.1f" % v)


def cell(g1_str, base_str):
    """G1 first; collapse to a single value when equal."""
    if g1_str == base_str:
        return g1_str
    return "%s / %s" % (g1_str, base_str)


u_g1   = parse_util(BENCH_G1)
u_base = parse_util(BENCH_BASE)
p_g1   = parse_dynamic(BENCH_G1)
p_base = parse_dynamic(BENCH_BASE)

if errors:
    for e in errors:
        sys.stderr.write("ERROR: %s\n" % e)
    sys.exit(1)


def lookup(util, leaves):
    """Sum the subtree totals of one or more sibling instances.

    leaves is None for the top cell, else a list of instance leaf names.
    """
    if leaves is None:
        rec = util.get("__TOP__")
        if rec is None:
            errors.append("top cell not found")
        return rec
    acc = dict(luts=0, ffs=0, ramb36=0, ramb18=0)
    for leaf in leaves:
        rec = util.get(leaf)
        if rec is None:
            errors.append("instance not found: %s" % (leaf,))
            return None
        for k in acc:
            acc[k] += rec[k]
    return acc


def row(metric):
    cells = []
    for name, leaves in COLUMNS:
        g1, base = lookup(u_g1, leaves), lookup(u_base, leaves)
        if g1 is None or base is None:
            cells.append("")
            continue
        if metric == "kLUTs":
            gs, bs = str(round(g1["luts"] / 1000)), str(round(base["luts"] / 1000))
        elif metric == "kFFs":
            gs, bs = str(round(g1["ffs"] / 1000)), str(round(base["ffs"] / 1000))
        elif metric == "BRAMs":
            if name in NO_BRAM_COLS:
                gs = bs = "0"
            else:
                gs, bs = fmt_bram(g1), fmt_bram(base)
        cells.append(cell(gs, bs))
    return cells


rows = [
    ["kLUTs"] + row("kLUTs"),
    ["kFFs"]  + row("kFFs"),
    ["BRAMs"] + row("BRAMs"),
]

# Power (W): total design Dynamic power, in the EPE Core column (matches
# the existing table layout), G1 / non-G1.
pwr_cell = cell("%.3f" % p_g1, "%.3f" % p_base)
rows.append(["Power (W)", pwr_cell, "", "", "", ""])

if errors:
    for e in errors:
        sys.stderr.write("ERROR: %s\n" % e)
    sys.exit(1)

header = ["Resource", "EPE Core", "Attention Core", "EAFC Core", "Sparse Core", "Total"]
lines = [",".join(header)] + [",".join(r) for r in rows]
text = "\n".join(lines) + "\n"

with open(OUT_CSV, "w", encoding="utf-8") as fh:
    fh.write(text)

print(text, end="")
print("Wrote %s" % OUT_CSV)
PY

echo "============================================================"
echo "table1 done: $OUT_CSV"
