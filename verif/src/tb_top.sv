`ifndef TB_TOP
`define TB_TOP

`timescale 1ns / 1ps
`include "tb_top_defines.svh"
`include "agent_defines.svh"

module tb_top;
 
    import test_pkg::*;
    import uvm_pkg::*;
    import zynq_bfm_pkg::*;

    reg aclk;
    reg aresetn;

    evt_agent_interface m_evt_if (aclk,aresetn);
    snn_agent_interface m_snn_if (aclk,aresetn);
    zynq_vip_bfm_wrapper m_zynq_vip_bfm_wrapper();

    initial begin
        force `FLOW_WRAPPER.s_axis_tdata = m_evt_if.axis_tdata;
        force `FLOW_WRAPPER.s_axis_tlast = m_evt_if.axis_tlast;
        force `FLOW_WRAPPER.s_axis_tvalid = m_evt_if.axis_tvalid;
        force m_evt_if.axis_tready = `FLOW_WRAPPER.s_axis_tready;

        force aclk = `FLOW_WRAPPER.aclk; // Use the PL clock from zynq
        force aresetn = `FLOW_WRAPPER.aresetn; // Use the PL reset from zynq

    end


`ifdef POST_IMPL
    initial begin
    force `FLOW_WRAPPER.\peripheral_aresetn[0]_bufg_place  = aresetn;
    force `FLOW_WRAPPER.\peripheral_aresetn[0]_bufg_place_replica  = aresetn;
    end
`endif

    `DUT_TOP DUT();

    // Starting the execution UVM phases
    initial begin
        uvm_config_db#(virtual evt_agent_interface)::set(null, "*" , "m_evt_if", m_evt_if);
        uvm_config_db#(virtual snn_agent_interface)::set(null, "*" , "m_snn_if", m_snn_if);
        uvm_config_db#(zynq_bfm_api)::set(null, "*" , "m_zynq_api", m_zynq_vip_bfm_wrapper.m_bfm_api);

        run_test();

    end

endmodule

`endif



