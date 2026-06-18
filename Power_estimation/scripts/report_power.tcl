# =====================================================================
# FPL_AE - post-synthesis power report from EDIF + SAIF
#
# Usage:
#   vivado -mode batch -source report_power.tcl -tclargs \
#       <benchmark> <saif_path> <power_out_path>
#
# Example:
#   vivado -mode batch -source report_power.tcl -tclargs \
#       ResNet18_CIFAR10 \
#       .../Netlist/ResNet18_CIFAR10/exspike_apec2_resnet18.saif \
#       .../Netlist/ResNet18_CIFAR10/power.txt
# =====================================================================

set SCRIPT_DIR [file normalize [file dirname [info script]]]
set POWER_DIR  [file normalize $SCRIPT_DIR/..]

set bench     [lindex $argv 0]
set saif_path [file normalize [lindex $argv 1]]
set out_path  [file normalize [lindex $argv 2]]

if {$bench eq "" || $saif_path eq "" || $out_path eq ""} {
    puts "ERROR: usage: vivado -mode batch -source report_power.tcl -tclargs <benchmark> <saif> <power.txt>"
    exit 1
}

set net_dir  $POWER_DIR/Netlist/$bench
set edf_path $net_dir/ExSpike_Top.edf
set clk_xdc  $POWER_DIR/clk.xdc

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

foreach f [list $edf_path $clk_xdc $saif_path] {
    if {![file exists $f]} {
        puts "ERROR: required file not found: $f"
        exit 1
    }
}

file mkdir [file dirname $out_path]

puts "============================================================"
puts " benchmark : $bench"
puts " link top  : $LINK_TOP"
puts " edf       : $edf_path"
puts " saif      : $saif_path"
puts " xdc       : $clk_xdc"
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

puts "INFO: read_xdc $clk_xdc"
read_xdc $clk_xdc

puts "INFO: read_saif ..."
read_saif -strip_path tb_top/inst_accelerator_top $saif_path

puts "INFO: report_power -> $out_path"
report_power -file $out_path -name power_1

puts "INFO: power report complete"
