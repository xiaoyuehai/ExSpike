set SCRIPT_DIR [file normalize [file dirname [info script]]]
set HW_DIR     [file normalize $SCRIPT_DIR/..]
set NETLIST    $HW_DIR/netlist
set IPDIR      $HW_DIR/xilinx_ip_xci
set OUTDIR     $HW_DIR/output
set BD_DCP     $IPDIR/bd/design_1/design_1.dcp
if {[info exists ::env(FPGA_PART)] && $::env(FPGA_PART) ne ""} {
    set PART $::env(FPGA_PART)
} else {
    set PART xc7v2000tfhg1761-2
}

set key [lindex $argv 0]

array set MAP {
    st4_cifar10       ExSpike_Top_ST4_CIFAR10.edf
    st2_cifar100      ExSpike_Top_ST2_CIFAR100.edf
    resnet18_cifar10  ExSpike_Top_ResNet18_CIFAR10.edf
    vgg11_cifar10     ExSpike_VGG11_CIFAR10.edf
    seg_land          ExSpike_Top_SEG_NET.edf
}

if {![info exists MAP($key)]} {
    puts "ERROR: unknown variant '$key'. valid: [array names MAP]"
    exit 1
}

set edf      $MAP($key)
set edf_path $NETLIST/$edf
set TOP      [file rootname $edf]
file mkdir $OUTDIR

create_project -in_memory -part $PART
read_edif $edf_path
read_checkpoint $BD_DCP
foreach dcp [lsort [glob -nocomplain $IPDIR/ip/*/*.dcp]] {
    read_checkpoint $dcp
}
link_design -top $TOP -part $PART
opt_design

report_utilization -hierarchical -hierarchical_depth 4 \
    -file $OUTDIR/${key}_util_hier.rpt
report_utilization -file $OUTDIR/${key}_util_postopt.rpt

puts "DONE hierarchical utilization -> $OUTDIR/${key}_util_hier.rpt"
