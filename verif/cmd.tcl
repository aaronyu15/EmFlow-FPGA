run 0

create_wave_config
set_property display_limit 99999999 [current_wave_config] 
set_property trace_limit 99999999 [current_sim] 

set flow_path /tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst
log_wave -r $flow_path -v
log_wave -r /tb_top/m_snn_if -v
log_wave -r /tb_top/m_evt_if -v


source cmd_wave.tcl

run -all