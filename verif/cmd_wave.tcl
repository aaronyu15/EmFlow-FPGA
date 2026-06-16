set flow_path /tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst

set IF_GRP [add_wave_group "Flow_Interface"]
add_wave -into $IF_GRP /tb_top/m_evt_if/aclk
add_wave -into $IF_GRP /tb_top/m_evt_if/aresetn
add_wave -into $IF_GRP /tb_top/m_evt_if/axis_*
add_wave -into $IF_GRP /tb_top/m_evt_if/evt_type
add_wave -into $IF_GRP -radix unsigned /tb_top/m_evt_if/evt_timestamp
add_wave -into $IF_GRP -radix unsigned /tb_top/m_evt_if/evt_x
add_wave -into $IF_GRP -radix unsigned /tb_top/m_evt_if/evt_y
add_wave -into $IF_GRP /tb_top/m_evt_if/evt_valid

set AXILITE_GRP [add_wave_group "AXILITE_Interface"]
add_wave -into $AXILITE_GRP ${flow_path}/aclk
add_wave -into $AXILITE_GRP ${flow_path}/aresetn
add_wave -into $AXILITE_GRP ${flow_path}/s_axi_*

set S_AXIS_GRP [add_wave_group "S_AXIS_Interface"]
add_wave -into $S_AXIS_GRP ${flow_path}/s_inst/*

set flow_snn ${flow_path}/u_flow_core/u_flow_snn
current_scope $flow_snn

set GRP [add_wave_group "SNN_IF"]
add_wave -into $GRP m_snn_if/

add_wave $flow_snn/layer_count
add_wave $flow_snn/fm_rd_sel

set GRP [add_wave_group "FLOW_SNN_GRP"]
add_wave -into $GRP $flow_snn/

set GRP [add_wave_group "FM_TOP_GRP"]
add_wave -into $GRP $flow_snn/fm_top_inst/
set GRP [add_wave_group "FM_MEM"]
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[0].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[1].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[2].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[3].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[4].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[5].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[6].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[7].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[8].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[9].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[10].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[11].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[12].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[13].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[14].u_feature_map /mem}} 
add_wave -into $GRP {{/tb_top/DUT/kv260_i/flow_wrapper_0/inst/inst/u_flow_core/u_flow_snn/fm_top_inst/\ram_loop[15].u_feature_map /mem}} 

set GRP [add_wave_group "FM_RD_GRP"]
add_wave -into $GRP $flow_snn/u_fm_reader

set GRP [add_wave_group "K0_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[0].kernel_inst 
set GRP [add_wave_group "K1_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[1].kernel_inst 
set GRP [add_wave_group "K2_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[2].kernel_inst 
set GRP [add_wave_group "K3_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[3].kernel_inst 
set GRP [add_wave_group "K4_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[4].kernel_inst 
set GRP [add_wave_group "K5_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[5].kernel_inst 
set GRP [add_wave_group "K6_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[6].kernel_inst 
set GRP [add_wave_group "K7_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[7].kernel_inst 
set GRP [add_wave_group "K8_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[8].kernel_inst 
set GRP [add_wave_group "K9_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[9].kernel_inst 
set GRP [add_wave_group "K10_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[10].kernel_inst 
set GRP [add_wave_group "K11_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[11].kernel_inst 
set GRP [add_wave_group "K12_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[12].kernel_inst 
set GRP [add_wave_group "K13_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[13].kernel_inst 
set GRP [add_wave_group "K14_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[14].kernel_inst 
set GRP [add_wave_group "K15_GRP"]
add_wave -into $GRP $flow_snn/\kernel_loop[15].kernel_inst 

set GRP [add_wave_group "SUM_GRP"]
add_wave -into $GRP $flow_snn/sum_inst/
add_wave $flow_snn/sum_inst/ram_sum_inst/mem_entries

set GRP [add_wave_group "Q_SCALE_GRP"]
add_wave -into $GRP $flow_snn/q_scale_inst/

set GRP [add_wave_group "MEMB_GRP"]
add_wave -into $GRP $flow_snn/membrane_top_inst/

set GRP [add_wave_group "FH_GRP"]
add_wave -into $GRP $flow_snn/flow_head_inst/

set GRP [add_wave_group "RAM_MST_GRP"]
add_wave -into $GRP $flow_snn/ram_mst_inst/

set GRP [add_wave_group "FH_FIFO_GRP"]
add_wave -into $GRP $flow_snn/flow_head_inst/xpm_fifo_sync_inst/xpm_fifo_base_inst