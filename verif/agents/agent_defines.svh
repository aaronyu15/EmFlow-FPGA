`ifndef AGENT_DEFINES
`define AGENT_DEFINES


`define ADDER_WIDTH 32
`define MAX_NO_OF_TRANSACTIONS 5

`define X_MAX 320
`define Y_MAX 320



// rtl
`define DUT_TOP top_wrapper
`define FLOW_WRAPPER $root.tb_top.DUT.kv260_i.flow_wrapper_0

`define FLOW_TOP `FLOW_WRAPPER.inst.inst
`define FLOW_CORE `FLOW_TOP.u_flow_core
`define FLOW_SNN `FLOW_CORE.u_flow_snn

`define IMG_BUF_0 `FLOW_TOP.image_buffer_inst.u0.mem
`define IMG_BUF_1 `FLOW_TOP.image_buffer_inst.u1.mem

`define K_WEIGHT(i) `FLOW_SNN.k_weight[i]
`define K_M0(i) `FLOW_SNN.k_m0[i]
`define K_SHIFT(i) `FLOW_SNN.k_shift[i]
`define K_THRESHOLD `FLOW_SNN.k_threshold

// feature map
`define FM_TOP_0 `FLOW_SNN.fm_top_inst
`define FM_MEM(i) `FM_TOP_0.ram_loop[i].u_feature_map.mem

// sum
`define SUM_TOP_0 `FLOW_SNN.sum_inst
`define SUM_MEM `SUM_TOP_0.ram_sum_inst.xpm_memory_sdpram_inst.xpm_memory_base_inst.mem

// membrane
`define MEMBRANE_TOP_0 `FLOW_SNN.membrane_top_inst
`define MEMBRANE_MEM `MEMBRANE_TOP_0.ram_mem_inst.xpm_memory_sdpram_inst.xpm_memory_base_inst.mem

// flow head
`define FLOW_HEAD_TOP_0 `FLOW_SNN.flow_head_inst
`define FLOW_HEAD_FM_MEM `FLOW_HEAD_TOP_0.ram_flow_head_inst.xpm_memory_sdpram_inst.xpm_memory_base_inst.mem




// verif
`define m_snn_if m_env.m_snn_agent.m_snn_if

`endif
