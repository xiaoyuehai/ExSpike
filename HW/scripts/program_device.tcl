# Vivado batch: program FPGA via hw_server
#
# argv:
#   0  absolute path to .bit file

set bit_file [lindex $argv 0]

if {$bit_file eq ""} {
    puts "ERROR: usage: program_device.tcl <path/to.bit>"
    exit 1
}

if {![file exists $bit_file]} {
    puts "ERROR: bitstream not found: $bit_file"
    exit 1
}

set bit_file [file normalize $bit_file]
puts "INFO: program bitstream $bit_file"

open_hw
connect_hw_server
open_hw_target

set dev_list [get_hw_devices -quiet]
if {[llength $dev_list] == 0} {
    puts "ERROR: no hw device found"
    exit 1
}

set hw_dev [lindex $dev_list 0]
current_hw_device $hw_dev
refresh_hw_device -update_hw_probes false $hw_dev

set_property PROBES.FILE {} $hw_dev
set_property FULL_PROBES.FILE {} $hw_dev
set_property PROGRAM.FILE $bit_file $hw_dev

puts "INFO: programming device $hw_dev ..."
program_hw_devices $hw_dev
refresh_hw_device $hw_dev

puts "INFO: program_device.tcl done"
