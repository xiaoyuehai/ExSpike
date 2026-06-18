# =====================================================================
# FPL_AE - post-synthesis hierarchical utilization from EDIF + IP
#
# Reads the EDIF netlist and its IP checkpoints, links the design in
# memory (NO synthesis / NO implementation), then writes a hierarchical
# utilization report. Used to build Power_estimation/table1.csv.
#
# Usage:
#   vivado -mode batch -source report_util.tcl -tclargs \
#       <benchmark> <util_out_path>
#
# Example:
#   vivado -mode batch -source report_util.tcl -tclargs \
#       ST4_CIFAR10 .../Netlist/ST4_CIFAR10/util_hier.rpt
# =====================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set POWER_DIR  [file normalize $SCRIPT_DIR/..]

set bench    [lindex $argv 0]
set out_path [file normalize [lindex $argv 1]]

if {$bench eq "" || $out_path eq ""} {
    puts "ERROR: usage: vivado -mode batch -source report_util.tcl -tclargs <benchmark> <util.rpt>"
    exit 1
}

set net_dir  $POWER_DIR/Netlist/$bench
set edf_path $net_dir/ExSpike_Top.edf

if {[info exists ::env(XILINX_IP)]} {
    set ip_dir [file normalize $::env(XILINX_IP)/ip]
} else {
    set ip_dir [file normalize $POWER_DIR/../HW/xilinx_ip_xci/ip]
}

if {[info exists ::env(FPGA_PART)]} {
    set PART $::env(FPGA_PART)
} else {
    set PART xc7v2000tfhg1761-2
}

# Linux: link_design -top must match the EDIF file name (case-sensitive).
set LINK_TOP [file rootname [file tail $edf_path]]

if {![file exists $edf_path]} {
    puts "ERROR: required file not found: $edf_path"
    exit 1
}

file mkdir [file dirname $out_path]

puts "============================================================"
puts " benchmark : $bench"
puts " link top  : $LINK_TOP"
puts " edf       : $edf_path"
puts " output    : $out_path"
puts "============================================================"

create_project -in_memory -part $PART

puts "INFO: read_edif ..."
read_edif $edf_path

# Netlist dir is SegNet/ but Xilinx IP cores use SEG_NET_* prefix.
# ST4_CIFAR10_G1 is a group-1 variant that reuses the ST4_CIFAR10 IP set.
set ip_prefix $bench
if {$bench eq "SegNet"} {
    set ip_prefix SEG_NET
} elseif {$bench eq "ST4_CIFAR10_G1"} {
    set ip_prefix ST4_CIFAR10
}

set dcp_list [lsort [glob -nocomplain \
    $ip_dir/${ip_prefix}_*/*.dcp \
    $ip_dir/MP_MEM/MP_MEM.dcp \
    $ip_dir/FC_MP_MEM/FC_MP_MEM.dcp \
]]

if {[llength $dcp_list] == 0} {
    puts "ERROR: no IP checkpoints found under $ip_dir for benchmark $bench"
    exit 1
}

foreach dcp $dcp_list {
    puts "INFO: read_checkpoint $dcp"
    read_checkpoint $dcp
}

puts "INFO: link_design -top $LINK_TOP ..."
link_design -top $LINK_TOP -part $PART

puts "INFO: report_utilization -hierarchical -> $out_path"
report_utilization -hierarchical -file $out_path

puts "INFO: utilization report complete"
