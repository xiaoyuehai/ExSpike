set curr_wave [current_wave_config]
if { [string length $curr_wave] == 0 } {
  if { [llength [get_objects]] > 0} {
    add_wave /
    set_property needs_save false [current_wave_config]
  } else {
     send_msg_id Add_Wave-1 WARNING "No top level signals found. Simulator will start without a wave window. If you want to open a wave window go to 'File->New Waveform Configuration' or type 'create_wave_config' in the TCL console."
  }
}
run 300 ns
open_saif "exspike_apec2_vgg11.saif"
set curr_xsim_wave_scope [current_scope]
current_scope /tb_top/inst_accelerator_top
log_saif [get_objects -r *]
current_scope $curr_xsim_wave_scope
unset curr_xsim_wave_scope

run 300us
close_saif