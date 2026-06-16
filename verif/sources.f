
# I am adding this to compile the zynq AXI VIP manually to get rid of annoying $display prints
# note that I also removed this lines from the apis file read_data:
# if(start_addr[3:0] != 0) begin
#   $display("[%0d] : %0s :: rd_data should be declared as 128-bit and the data position is aligned to the address \n",$time, DISP_INFO);
# end

# Need these for RTL sims
#/Xilinx/Vivado/2024.1/data/ip/xilinx/zynq_ultra_ps_e_vip_v1_0/hdl/zynq_ultra_ps_e_vip_v1_0_vl_rfs.sv
#/Xilinx_2022.2/Vivado/2022.2/data/ip/xilinx/zynq_ultra_ps_e_vip_v1_0/hdl/zynq_ultra_ps_e_vip_v1_0_vl_rfs.sv

./agents/evt/evt_agent_interface.sv

./agents/snn/snn_agent_interface.sv
    ../rtl/src/design_pkg.sv
	agents/agent_defines.svh I

./agents/agent_pkg.sv
    ../rtl/src/design_pkg.sv
	agents/agent_defines.svh I
	agents/evt/evt_agent_transaction.sv I
	agents/evt/evt_agent_sequencer.sv I
	agents/evt/evt_agent_driver.sv I
	agents/evt/evt_agent_monitor.sv I
	agents/evt/evt_agent.sv I
	agents/snn/snn_agent.sv I
	agents/snn/snn_agent_monitor.sv I

./src/env_pkg.sv
    ../rtl/src/design_pkg.sv
	agents/agent_pkg.sv
	src/scoreboard.sv I
	src/env.sv I
	
./tests/seq_pkg.sv
	agents/agent_defines.svh I
	agents/agent_pkg.sv 
	src/env_pkg.sv
    tests/evt_sequence.sv I

./src/zynq_vip_bfm_wrapper.sv

./tests/test_pkg.sv
    ../rtl/src/design_pkg.sv
    src/zynq_vip_bfm_wrapper.sv I
	src/env_pkg.sv
	agents/agent_defines.svh I
	tests/test_basic.sv I
	tests/test_inference.sv I
	tests/test_mmap_reg.sv I
	tests/test_dma.sv I
	tests/seq_pkg.sv I

./src/tb_top.sv
    ./agents/evt/evt_agent_interface.sv I
    ./agents/snn/snn_agent_interface.sv I
	src/tb_top_defines.svh I
    agents/agent_defines.svh I
	tests/test_pkg.sv
    src/zynq_vip_bfm_wrapper.sv I
    ../rtl/src/top_wrapper.v I

# RTL Sources
../rtl/src/design_pkg.sv

../rtl/src/top_wrapper.v
    ../rtl/src/flow_wrapper.v I
    #../outputs/post_synth/post_synth_block.v I
    #../outputs/main_block_netlist.v I

../rtl/src/flow_wrapper.v
    ../rtl/src/flow_top.sv I

../rtl/src/flow_top.sv
    ../rtl/src/design_pkg.sv
    ../rtl/src/flow_m_axis.sv I
    ../rtl/src/flow_s_axis.sv I
    ../rtl/src/flow_s_axilite.sv I
    ../rtl/src/image_buffer.sv I
    ../rtl/src/flow_core.sv I

../rtl/src/image_buffer.sv
    ../rtl/src/mem/ram_image.sv I
    ../rtl/src/design_pkg.sv

../rtl/src/flow_core.sv
    ../rtl/src/design_pkg.sv
    ../rtl/src/flow_snn.sv I
    ../rtl/src/timer_inf.sv I

../rtl/src/mem/ram_image.sv
    ../rtl/src/design_pkg.sv

../rtl/src/flow_snn.sv
    ../rtl/src/design_pkg.sv
    ../rtl/src/mem/ram_layer.sv I
    ../rtl/src/mem/ram_weight.sv I
    ../rtl/src/mem/ram_mst.sv I
    ../rtl/src/datapath/fm_top.sv I
    ../rtl/src/datapath/fm_reader.sv I
    ../rtl/src/datapath/kernel.sv I
    ../rtl/src/datapath/sum.sv I
    ../rtl/src/datapath/q_scale.sv I
    ../rtl/src/datapath/membrane_top.sv I
    ../rtl/src/datapath/flow_head.sv I

../rtl/src/flow_m_axis.sv
    ../rtl/src/design_pkg.sv
../rtl/src/flow_s_axis.sv
    ../rtl/src/design_pkg.sv
../rtl/src/flow_s_axilite.sv
    ../rtl/src/design_pkg.sv

../rtl/src/timer_inf.sv

../rtl/src/datapath/fm_reader.sv
    ../rtl/src/design_pkg.sv

../rtl/src/datapath/kernel.sv
    ../rtl/src/design_pkg.sv

../rtl/src/datapath/fm_top.sv
    ../rtl/src/mem/ram_fm.sv I
    ../rtl/src/design_pkg.sv

../rtl/src/datapath/sum.sv
    ../rtl/src/mem/ram_sum.sv I
    ../rtl/src/mem/rom_addr.sv I
    ../rtl/src/design_pkg.sv

../rtl/src/datapath/q_scale.sv
    ../rtl/src/design_pkg.sv

../rtl/src/datapath/membrane_top.sv
    ../rtl/src/mem/ram_membrane.sv I
    ../rtl/src/design_pkg.sv

../rtl/src/datapath/flow_head.sv
    ../rtl/src/design_pkg.sv
    ../rtl/src/mem/ram_flow_head.sv I

../rtl/src/mem/ram_layer.sv
    ../rtl/src/design_pkg.sv
../rtl/src/mem/ram_weight.sv
    ../rtl/src/design_pkg.sv
../rtl/src/mem/ram_mst.sv
    ../rtl/src/design_pkg.sv
../rtl/src/mem/ram_fm.sv
    ../rtl/src/design_pkg.sv
../rtl/src/mem/ram_sum.sv
    ../rtl/src/design_pkg.sv
../rtl/src/mem/ram_membrane.sv
    ../rtl/src/design_pkg.sv
../rtl/src/mem/rom_addr.sv
    ../rtl/src/design_pkg.sv
../rtl/src/mem/ram_flow_head.sv
    ../rtl/src/design_pkg.sv


# Post synth
#../outputs/post_synth/post_synth_block.v

# Post impl
#../outputs/main_block_netlist.v






