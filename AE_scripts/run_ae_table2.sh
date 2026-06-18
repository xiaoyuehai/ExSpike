#!/usr/bin/env bash
# =====================================================================
# Usage:
#   ./run_ae_table2.sh            # build Artifacts/table2.csv (measured)
#   ./run_ae_table2.sh --provided # build from *_provided inputs (no rerun)
#   ./run_ae_table2.sh --check    # validate inputs only, do not write
#   ./run_ae_table2.sh --help
#
# Per-column data sources (ExSpike rows only):
#   PE Size     fixed at 352
#   kLUTs/kFFs  HW/output/<b>_util_hier.rpt  (U_EVENT_PROCESSOR_TOP row)
#   BRAM        RAMB36 + 0.5*RAMB18 of that same row
#   DSPs        DSP48 Blocks of that same row
#   FPS         Log/<b>.log  -> "throughput = <x> imgs/s"
#   GOPS        FPS * <model GOP from sourceme>
#   GOPS/W      GOPS / Dynamic(W) from Power_estimation/Netlist/<d>/power.txt
#   GOPS/W/PE   GOPS/W / PE Size
#   Acc.        Log/<b>.log [SUMMARY] line (classification % or pixAcc%)
# =====================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../sourceme"

CHECK_ONLY=0
USE_PROVIDED=0
for a in "$@"; do
    case "$a" in
        --check) CHECK_ONLY=1 ;;
        --provided) USE_PROVIDED=1 ;;
        -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
        *) echo "ERROR: unknown argument '$a'"; sed -n '2,25p' "$0"; exit 1 ;;
    esac
done

OUT_CSV="$ARTIFACTS/table2.csv"
mkdir -p "$ARTIFACTS"

export EXSPIKE_OUT_CSV="$OUT_CSV"
export EXSPIKE_CHECK_ONLY="$CHECK_ONLY"
export EXSPIKE_USE_PROVIDED="$USE_PROVIDED"

"$PYTHON" - <<'PY'
import os
import re
import sys

ROOT      = os.environ["ROOT_DIR"]
HW_OUT    = os.path.join(os.environ["HW_IMPLE"], "output")
LOG_DIR   = os.path.join(ROOT, "Log")
POWER_NET = os.path.join(os.environ["POWER"], "Netlist")
OUT_CSV   = os.environ["EXSPIKE_OUT_CSV"]
CHECK_ONLY = os.environ.get("EXSPIKE_CHECK_ONLY", "0") == "1"
USE_PROVIDED = os.environ.get("EXSPIKE_USE_PROVIDED", "0") == "1"

UTIL_SUFFIX  = "_util_hier_provided.rpt" if USE_PROVIDED else "_util_hier.rpt"
LOG_SUFFIX   = "_provided.log" if USE_PROVIDED else ".log"
POWER_FNAME  = "power_provided.txt" if USE_PROVIDED else "power.txt"

PE_SIZE = 352

# Each ExSpike row: (util prefix, log name, power dir, GOP env var, metadata...)
ROWS = [
    dict(util="vgg11_cifar10",    log="vgg11_cifar10",    power="VGG11_CIFAR10",
         gop_env="VGG11_CIFAR10_OPs",
         device="xc7v2000t", clk=200, dataset="CIFAR-10",  model="VGG11",                acc="93.88"),
    dict(util="resnet18_cifar10", log="resnet18_cifar10", power="ResNet18_CIFAR10",
         gop_env="ResNet18_CIFAR10_OPs",
         device="xc7v2000t", clk=200, dataset="CIFAR-10",  model="ResNet18",             acc="94.82"),
    dict(util="st4_cifar10",      log="st4_cifar10",      power="ST4_CIFAR10",
         gop_env="ST4_CIFAR10_OPs",
         device="xc7v2000t", clk=200, dataset="CIFAR-10",  model="SpikingFormer-4-256",  acc="94.23"),
    dict(util="st2_cifar100",     log="st2_cifar100",     power="ST2_CIFAR100",
         gop_env="ST2_CIFAR100_OPs",
         device="xc7v2000t", clk=200, dataset="CIFAR-100", model="SpikingFormer-2-512",  acc="75.23"),
    dict(util="seg_land",         log="seg_land",         power="SegNet",
         gop_env="SEG_NET_OPs",
         device="xc7v2000t", clk=200, dataset="MLND_Capstone", model="SegNet",           acc="98.68"),
]

HEADER = ["Work", "Device", "Clk (MHz)", "Dataset", "Model", "Acc.", "PE Size",
          "kLUTs", "kFFs", "BRAM", "DSPs", "FPS", "GOPS", "GOPS/W", "GOPS/W/PE"]

errors = []


def parse_event_processor(util_path):
    """Return dict with luts, ffs, ramb36, ramb18, dsp for U_EVENT_PROCESSOR_TOP."""
    with open(util_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if not line.startswith("|"):
                continue
            cols = [c.strip() for c in line.split("|")]
            # cols[0]='' cols[1]=Instance cols[2]=Module cols[3]=Total LUTs ...
            if len(cols) < 11:
                continue
            if cols[1] == "U_EVENT_PROCESSOR_TOP":
                return dict(
                    luts=int(cols[3]),
                    ffs=int(cols[7]),
                    ramb36=int(cols[8]),
                    ramb18=int(cols[9]),
                    dsp=int(cols[10]),
                )
    return None


def parse_fps(log_path):
    fps = None
    pat = re.compile(r"throughput\s*=\s*([0-9.]+)\s*imgs/s")
    with open(log_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = pat.search(line)
            if m:
                fps = float(m.group(1))  # keep last occurrence
    return fps


def parse_acc(log_path):
    """Extract final accuracy from the [SUMMARY] line.

    classification: '[SUMMARY] 9389/10000 = 93.89%'
    segmentation  : '[SUMMARY] images=2553  pixAcc=98.70%  IoU_fg=0.9189'
    """
    acc = None
    with open(log_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if "[SUMMARY]" not in line:
                continue
            m = re.search(r"pixAcc=\s*([0-9.]+)\s*%", line)
            if not m:
                m = re.search(r"=\s*([0-9.]+)\s*%", line)
            if m:
                acc = m.group(1)
    return acc


def parse_dynamic_power(power_path):
    pat = re.compile(r"Dynamic \(W\)\s*\|\s*([0-9.]+)")
    with open(power_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            m = pat.search(line)
            if m:
                return float(m.group(1))
    return None


def parse_gop(env_name):
    raw = os.environ.get(env_name, "")
    m = re.match(r"\s*([0-9.]+)", raw)
    return float(m.group(1)) if m else None


def fmt(x, nd):
    return f"{x:.{nd}f}"


out_rows = []
for r in ROWS:
    util_path  = os.path.join(HW_OUT, f"{r['util']}{UTIL_SUFFIX}")
    log_path   = os.path.join(LOG_DIR, f"{r['log']}{LOG_SUFFIX}")
    power_path = os.path.join(POWER_NET, r["power"], POWER_FNAME)

    util = fps = dyn = gop = None
    acc = r["acc"]  # published fallback

    if not os.path.isfile(util_path):
        errors.append(f"[{r['model']}] missing util report: {util_path}")
    else:
        util = parse_event_processor(util_path)
        if util is None:
            errors.append(f"[{r['model']}] U_EVENT_PROCESSOR_TOP row not found in {util_path}")

    if not os.path.isfile(log_path):
        errors.append(f"[{r['model']}] missing log: {log_path}")
    else:
        fps = parse_fps(log_path)
        if fps is None:
            errors.append(f"[{r['model']}] throughput not found in {log_path}")
        measured_acc = parse_acc(log_path)
        if measured_acc is not None:
            acc = measured_acc

    if not os.path.isfile(power_path):
        errors.append(f"[{r['model']}] missing power.txt: {power_path}")
    else:
        dyn = parse_dynamic_power(power_path)
        if dyn is None:
            errors.append(f"[{r['model']}] Dynamic (W) not found in {power_path}")

    gop = parse_gop(r["gop_env"])
    if gop is None:
        errors.append(f"[{r['model']}] GOP env not set: {r['gop_env']}")

    if None in (util, fps, dyn, gop):
        continue

    klut = util["luts"] / 1000.0
    kff  = util["ffs"] / 1000.0
    bram = int(util["ramb36"] + 0.5 * util["ramb18"])  # 36Kb-equiv, floored
    dsp  = util["dsp"]

    gops      = fps * gop
    gops_w    = gops / dyn if dyn else 0.0
    gops_w_pe = gops_w / PE_SIZE

    out_rows.append([
        "ExSpike", r["device"], str(r["clk"]), r["dataset"], r["model"], str(acc),
        str(PE_SIZE),
        str(round(klut)), str(round(kff)),
        str(bram), str(dsp),
        fmt(fps, 2), fmt(gops, 2), fmt(gops_w, 2), fmt(gops_w_pe, 3),
    ])

if errors:
    sys.stderr.write("Input problems:\n")
    for e in errors:
        sys.stderr.write("  " + e + "\n")

if not out_rows:
    sys.stderr.write("ERROR: no ExSpike rows could be generated.\n")
    sys.exit(1)

# pretty print to stdout
widths = [max(len(HEADER[i]), max(len(row[i]) for row in out_rows)) for i in range(len(HEADER))]
def line(cells):
    return "  ".join(c.ljust(widths[i]) for i, c in enumerate(cells))
print(line(HEADER))
print(line(["-" * w for w in widths]))
for row in out_rows:
    print(line(row))

if CHECK_ONLY:
    print("\n[check] inputs OK; CSV not written.")
    sys.exit(0)

import csv
with open(OUT_CSV, "w", newline="") as fh:
    w = csv.writer(fh)
    w.writerow(HEADER)
    w.writerows(out_rows)
print(f"\nWrote: {OUT_CSV} ({len(out_rows)} ExSpike rows)")
PY