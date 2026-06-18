# =====================================================================
# FPL_AE - post-synthesis (implementation-only) bitstream generation
#
# Non-project batch flow (consumes the provided generated products):
#   read_edif    <variant top netlist>      ; Synplify EDIF top, top = file name
#   read_checkpoint  <BD + all IP .dcp>      ; fill black boxes (design_1, *_MEM)
#   link_design
#   read_xdc     pin.xdc                      ; user top-level pin constraints
#   read_xdc     MIG  ddr3 constraints        ; top-level (get_ports / get_cells -hier)
#   read_xdc     CDC false_paths (global)     ; proc_sys_reset + smartconnect psr*
#   read_xdc -cells <pcie inst>  PCIe gt cons ; scoped to the XDMA pcie2 IP instance
#   read_xdc -cells <xdma inst>  fifo rst fp  ; scoped to the XDMA IP instance
#   opt -> place -> phys_opt -> route -> write_bitstream
#
# All IP-delivered timing constraints used by the GUI project run at IMPLEMENTATION
# are re-applied here (the _ooc.xdc / _board.xdc files are deliberately skipped:
# they are for each IP's out-of-context synthesis or for dev-board pins only).
# Missing the CDC false_paths makes the synchroniser paths (e.g. xdma user_reset
# -> smartconnect *cdc_to*/D) appear as the worst negative slack; reading them
# both removes those false violations and lets the placer focus on real paths.
#
# The IP/BD .dcp are reused directly (no regeneration), so the Windows .coe
# paths inside the .xci are never touched.  The physical constraints for the
# hard blocks (MIG DDR3 Phaser/IO, PCIe GT) live INSIDE the BD and must be
# re-applied here because read_checkpoint of an OOC dcp does not carry them up.
#
# In Vivado's netlist flow link_design -top matches the EDIF *file name*
# (e.g. ExSpike_Top_ST4_CIFAR10), not the internal (design ...) cell.
#
# Usage:
#   vivado -mode batch -source impl_variant.tcl -tclargs <variant_key> [jobs]
# =====================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set HW_DIR     [file normalize $SCRIPT_DIR/..]
set NETLIST    $HW_DIR/netlist
set IPDIR      $HW_DIR/xilinx_ip_xci
set XDC        $HW_DIR/constraints/pin.xdc
set OUTDIR     $HW_DIR/output

set BD_DCP     $IPDIR/bd/design_1/design_1.dcp
set MIG_XDC    $IPDIR/bd/design_1/ip/design_1_mig_7series_0_0/design_1_mig_7series_0_0/user_design/constraints/design_1_mig_7series_0_0.xdc
set PCIE_XDC   $IPDIR/bd/design_1/ip/design_1_xdma_0_0/ip_0/source/design_1_xdma_0_0_pcie2_ip-PCIE_X0Y1.xdc

# --- IP-delivered timing constraints applied at TOP implementation (non-ooc) ---
# CDC false-paths.  All use the global pattern  -to [get_pins -hier *cdc_to*/D]
# so they are safe (and intended) to read unscoped at the top.  These remove the
# proc_sys_reset / smartconnect synchroniser CDC paths from timing - exactly the
# paths that otherwise show up as the worst negative slack (e.g. -3.1ns) and that
# the GUI project run false-paths away.
set GLOBAL_XDC [list \
    $IPDIR/bd/design_1/ip/design_1_proc_sys_reset_0_0/design_1_proc_sys_reset_0_0.xdc \
    $IPDIR/bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_1/bd_886d_psr0_0.xdc \
    $IPDIR/bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_2/bd_886d_psr_aclk_0.xdc \
    $IPDIR/bd/design_1/ip/design_1_smartconnect_0_1/bd_0/ip/ip_3/bd_886d_psr_aclk1_0.xdc \
]
# XDMA internal FIFO reset false-paths: reference the xdma IP port (s_aresetn) and
# *rstblk* cells, so they must be read scoped to the xdma IP instance.
set XDMA_XDC [list \
    $IPDIR/bd/design_1/ip/design_1_xdma_0_0/ip_3/pcie2_fifo_generator_dma_cpl.xdc \
    $IPDIR/bd/design_1/ip/design_1_xdma_0_0/ip_4/pcie2_fifo_generator_tgt_brdg.xdc \
]

if {[info exists ::env(FPGA_PART)] && $::env(FPGA_PART) ne ""} {
    set PART $::env(FPGA_PART)
} else {
    set PART xc7v2000tfhg1761-2
}

# ---------- args ----------
set key  [lindex $argv 0]
set jobs [lindex $argv 1]
if {$jobs eq ""} { set jobs 2 }

# ---------- variant map: key -> {edf bitname} ----------
array set MAP {
    st4_cifar10       {ExSpike_Top_ST4_CIFAR10.edf      ExSpike_Top_ST4_CIFAR10.bit}
    st2_cifar100      {ExSpike_Top_ST2_CIFAR100.edf     ExSpike_Top_ST2_CIFAR100.bit}
    resnet18_cifar10  {ExSpike_Top_ResNet18_CIFAR10.edf ExSpike_Top_ResNet18_CIFAR10.bit}
    vgg11_cifar10     {ExSpike_Top_VGG11_CIFAR10.edf    ExSpike_Top_VGG11_CIFAR10.bit}
    seg_land          {ExSpike_Top_SEG_NET.edf          ExSpike_Top_SEG_NET.bit}
}

if {![info exists MAP($key)]} {
    puts "ERROR: unknown variant '$key'. valid keys: [array names MAP]"
    exit 1
}

set edf      [lindex $MAP($key) 0]
set bit      [lindex $MAP($key) 1]
set edf_path $NETLIST/$edf
set out_bit  $OUTDIR/$bit
set TOP      [file rootname $edf]

foreach f [list $edf_path $XDC $BD_DCP $MIG_XDC $PCIE_XDC] {
    if {![file exists $f]} { puts "ERROR: required file not found: $f"; exit 1 }
}
file mkdir $OUTDIR

set t_start [clock seconds]
puts "============================================================"
puts " variant : $key      top module: $TOP"
puts " edf     : $edf_path"
puts " part    : $PART      jobs: $jobs"
puts " out bit : $out_bit"
puts "============================================================"

# ---------- 1) top netlist ----------
create_project -in_memory -part $PART
puts "INFO: read_edif (top netlist) ..."
read_edif $edf_path

# ---------- 2) black-box fillers: BD + all user IP checkpoints ----------
puts "INFO: read_checkpoint (BD)  $BD_DCP"
read_checkpoint $BD_DCP
foreach dcp [lsort [glob -nocomplain $IPDIR/ip/*/*.dcp]] {
    puts "INFO: read_checkpoint (IP)  $dcp"
    read_checkpoint $dcp
}

# ---------- 3) link ----------
puts "INFO: link_design -top $TOP -part $PART ..."
link_design -top $TOP -part $PART

# ---------- 4) constraints ----------
puts "INFO: read_xdc (top pins) $XDC"
read_xdc $XDC

# MIG DDR3 physical/timing constraints: written against top ports + get_cells -hier
puts "INFO: read_xdc (MIG)      $MIG_XDC"
read_xdc $MIG_XDC

# Global IP CDC false-paths (proc_sys_reset / smartconnect synchronisers).
# Read unscoped: their object queries are top-wide (get_pins -hier *cdc_to*/D).
foreach gx $GLOBAL_XDC {
    if {![file exists $gx]} { puts "WARNING: missing CDC xdc: $gx"; continue }
    puts "INFO: read_xdc (CDC false_path) $gx"
    if {[catch {read_xdc $gx} emsg]} { puts "WARNING: read failed ($gx): $emsg" }
}

# PCIe (XDMA) GT constraints: scoped, refs start with 'inst/...'. Locate the
# enclosing pcie2 IP instance and apply the file scoped to that cell.
set pcie_scope ""
catch {
    set gtc [get_cells -hier -filter {NAME =~ */inst/gt_top_i/pipe_wrapper_i/pipe_lane*gt_wrapper_i/*gtxe2_channel_i}]
    if {[llength $gtc] > 0} {
        set one [lindex $gtc 0]
        if {[regexp {^(.*)/inst/gt_top_i} $one -> sc]} { set pcie_scope $sc }
    }
}
if {$pcie_scope ne ""} {
    puts "INFO: read_xdc -cells {$pcie_scope} (PCIe)  $PCIE_XDC"
    if {[catch {read_xdc -cells $pcie_scope $PCIE_XDC} emsg]} {
        puts "WARNING: scoped PCIe xdc read failed: $emsg"
    }
} else {
    puts "WARNING: could not locate PCIe pcie2 IP scope cell; skipping $PCIE_XDC"
    puts "WARNING: (placement may fail on unconstrained GT - will revisit if so)"
}

# XDMA internal FIFO reset false-paths: scope to the xdma IP instance, which is
# the ancestor cell '.../xdma_0/inst' of the pcie2 scope located above.
set xdma_scope ""
if {$pcie_scope ne ""} {
    if {![regexp {^(.*/xdma_0/inst)/} $pcie_scope -> xdma_scope]} { set xdma_scope "" }
}
if {$xdma_scope ne ""} {
    foreach xx $XDMA_XDC {
        if {![file exists $xx]} { puts "WARNING: missing xdma xdc: $xx"; continue }
        puts "INFO: read_xdc -cells {$xdma_scope} (XDMA fifo) $xx"
        if {[catch {read_xdc -cells $xdma_scope $xx} emsg]} {
            puts "WARNING: scoped xdma xdc read failed ($xx): $emsg"
        }
    }
} else {
    puts "WARNING: could not locate xdma_0/inst scope; skipping XDMA fifo false_paths"
}

# ---------- 5) implementation: "Performance_NetDelay_low" strategy ----------
# Aligned to the GUI reference run HW/xilinx_ip_xci/ref_log/runme_vgg11.log
# (Post-Route WNS=-0.410). This is the Vivado Performance_NetDelay_low strategy:
#   opt_design      -directive Explore
#   place_design    -directive ExtraNetDelay_low
#   phys_opt_design -directive AggressiveExplore
#   route_design    -directive NoTimingRelaxation
puts "INFO: opt_design ...";       opt_design       -directive Explore
puts "INFO: place_design ...";     place_design     -directive ExtraNetDelay_low
puts "INFO: phys_opt_design ...";  phys_opt_design  -directive AggressiveExplore
puts "INFO: route_design ...";     route_design     -directive NoTimingRelaxation

# ---------- 6) reports + routed checkpoint ----------
report_timing_summary -file $OUTDIR/${key}_timing.rpt
report_utilization    -file $OUTDIR/${key}_util.rpt
report_utilization    -hierarchical -hierarchical_depth 4 -file $OUTDIR/${key}_util_hier.rpt
report_drc            -file $OUTDIR/${key}_drc.rpt
write_checkpoint -force $OUTDIR/${key}_routed.dcp

# ---------- 7) bitstream ----------
puts "INFO: write_bitstream -> $out_bit"
write_bitstream -force $out_bit

set elapsed [expr {[clock seconds] - $t_start}]
set wns "n/a"
catch { set wns [get_property SLACK [lindex [get_timing_paths -max_paths 1 -nworst 1 -setup] 0]] }
puts "============================================================"
puts " DONE  variant=$key  bit=$out_bit"
puts " setup WNS : $wns ns"
puts " elapsed   : ${elapsed}s ([format %.2f [expr {$elapsed/60.0}]] min)"
puts "============================================================"
