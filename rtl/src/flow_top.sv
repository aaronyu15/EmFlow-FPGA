// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1ps / 1ps `default_nettype none

import design_pkg::*;

module flow_top #(
    parameter C_AXIS_TDATA_WIDTH   = 64,  // Match TDATA_WIDTH of DMA's AXIS interface
    parameter C_AXILITE_ADDR_WIDTH = 32,
    parameter C_AXILITE_DATA_WIDTH = 32
) (
    // Global Signals from Block Design
    input wire aclk,    // Connected to Block Design Clock (e.g., clk_out from Clocking Wizard)
    input wire aresetn, // Connected to Block Design Reset (e.g., peripheral_aresetn from Proc Sys Reset)

//`ifdef USE_2X_CLK
//    input wire aclk_2x,
//    input wire aresetn_2x,
//`endif

    // AXI4-Lite Write Address Channel
    input  wire [C_AXILITE_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                            s_axi_awvalid,
    output wire                            s_axi_awready,

    // AXI4-Lite Write Data Channel
    input  wire [C_AXILITE_DATA_WIDTH-1:0] s_axi_wdata,
    input  wire                            s_axi_wvalid,
    output wire                            s_axi_wready,

    // AXI4-Lite Write Response Channel
    output wire [1:0] s_axi_bresp,
    output wire       s_axi_bvalid,
    input  wire       s_axi_bready,

    // AXI4-Lite Read Address Channel
    input  wire [C_AXILITE_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                            s_axi_arvalid,
    output wire                            s_axi_arready,

    // AXI4-Lite Read Data Channel
    output wire [C_AXILITE_DATA_WIDTH-1:0] s_axi_rdata,
    output wire [                     1:0] s_axi_rresp,
    output wire                            s_axi_rvalid,
    input  wire                            s_axi_rready,


    output reg  [C_AXIS_TDATA_WIDTH-1:0] m_axis_tdata,
    output reg                           m_axis_tlast,
    output reg                           m_axis_tvalid,
    input  wire                          m_axis_tready,

    input  wire [C_AXIS_TDATA_WIDTH-1:0] s_axis_tdata,
    input  wire                          s_axis_tlast,
    input  wire                          s_axis_tvalid,
    output reg                           s_axis_tready
);

    (* dont_touch = "true" *) logic en;

    logic enable_count;
    logic [31:0] event_count;
    logic [31:0] busy_count;
    logic [31:0] idle_count;
    logic [31:0] inference_count;
    logic [31:0] layer_e1_count;
    logic [31:0] layer_e2_count;
    logic [31:0] layer_m1_count;
    logic [31:0] layer_m2_count;
    logic [31:0] layer_m3_count;
    logic [31:0] layer_m4_count;
    logic [31:0] layer_d1_count;
    logic [31:0] layer_h_count;
    logic [31:0] layer_h_stall;

    logic [31:0] layer_e1_spike_count;
    logic [31:0] layer_e2_spike_count;
    logic [31:0] layer_m1_spike_count;
    logic [31:0] layer_m2_spike_count;
    logic [31:0] layer_m3_spike_count;
    logic [31:0] layer_m4_spike_count;
    logic [31:0] layer_d1_spike_count;


    logic evt_data_valid;
    logic [63:0] evt_data_s;
    evt_data_t evt_data;
    logic evt_data_ready;

    logic [11:0] addr_readout;
    logic addr_readout_valid;
    logic [31:0] data_readout;
    logic data_readout_valid;

    logic axis_m_ready;

    // Control-plane placeholders for flow_core
    logic busy;
    logic buf_swap;
    logic buf_swap_ack;

    logic [8:0] fh_x;
    logic [8:0] fh_y;
    logic [MEMB_I-1:0] fh_u;
    logic [MEMB_I-1:0] fh_v;
    logic fh_valid;
    logic fh_done_proc;

    logic read_reset;
    logic [3:0] timestep_count;
    logic [31:0] timer_count;

    flow_s_axilite #(
        .C_S_AXI_DATA_WIDTH(C_AXILITE_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_AXILITE_ADDR_WIDTH)
    ) flow_axilite_slave_inst (
        .aclk         (aclk),
        .aresetn      (aresetn),
        .s_axi_awaddr (s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata  (s_axi_wdata),
        .s_axi_wvalid (s_axi_wvalid),
        .s_axi_wready (s_axi_wready),
        .s_axi_bresp  (s_axi_bresp),
        .s_axi_bvalid (s_axi_bvalid),
        .s_axi_bready (s_axi_bready),
        .s_axi_araddr (s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata  (s_axi_rdata),
        .s_axi_rresp  (s_axi_rresp),
        .s_axi_rvalid (s_axi_rvalid),
        .s_axi_rready (s_axi_rready),

        // Registers
        .en            (en),
        .busy          (busy),
        .enable_count   (enable_count),
        .event_count   (event_count),     // input unique spike count over the last x ms
        .busy_count    (busy_count),      // clock cycles spent busy over the last x ms
        .idle_count    (idle_count),      // clock cycles spent idle over the last x ms
        .inference_count(inference_count),
        .layer_e1_count(layer_e1_count),  // clock cycles spent in layer 1 over the last x ms
        .layer_e2_count(layer_e2_count),  // clock cycles spent in layer 2 over the last x ms
        .layer_m1_count(layer_m1_count),  // clock cycles spent in layer 3 over the last x ms
        .layer_m2_count(layer_m2_count),  // clock cycles spent in layer 4 over the last x ms
        .layer_m3_count(layer_m3_count),  // clock cycles spent in layer 5 over the last x ms
        .layer_m4_count(layer_m4_count),  // clock cycles spent in layer 6 over the last x ms
        .layer_d1_count(layer_d1_count),  // clock cycles spent in layer 7 over the last x ms
        .layer_h_count (layer_h_count),    // clock cycles spent in layer 8 over the last x ms
        .layer_h_stall(layer_h_stall), // clock cycles spent stalled in layer 8 over the last x ms
        .timer_count    (timer_count),      // timer count in microseconds for performance measurement

        .layer_e1_spike_count(layer_e1_spike_count),
        .layer_e2_spike_count(layer_e2_spike_count),
        .layer_m1_spike_count(layer_m1_spike_count),
        .layer_m2_spike_count(layer_m2_spike_count),
        .layer_m3_spike_count(layer_m3_spike_count),
        .layer_m4_spike_count(layer_m4_spike_count),
        .layer_d1_spike_count(layer_d1_spike_count)

    );



    flow_s_axis #(
        .C_AXIS_TDATA_WIDTH(C_AXIS_TDATA_WIDTH)
    ) s_inst (
        .aclk         (aclk),
        .aresetn      (aresetn),
        .s_axis_tdata (s_axis_tdata),
        .s_axis_tlast (s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
    
        .data_o (evt_data_s),
        .ready_i(evt_data_ready),
        .valid_o(evt_data_valid),
        .last_o ()
    );

    assign evt_data = evt_data_t'(evt_data_s);



    image_buffer image_buffer_inst (

        .clk         (aclk),
        .rstn        (aresetn),

        .en          (en),
        .buf_swap    (buf_swap),
        .buf_swap_ack(buf_swap_ack),

        .evt_data_valid(evt_data_valid),
        .evt_data      (evt_data),
        .evt_data_ready(evt_data_ready),

        .read_reset        (read_reset),
        .addr_readout      (addr_readout),
        .addr_readout_valid(addr_readout_valid),
        .data_readout      (data_readout),
        .data_readout_valid(data_readout_valid)
    );

    // Core instantiation; generates control pulses and status.
    flow_core u_flow_core (
        .clk  (aclk),
        .rst_n(aresetn),

        .en   (en),
        .busy (busy),

        .buf_swap    (buf_swap),
        .buf_swap_ack(buf_swap_ack),

        .read_reset        (read_reset),
        .addr_readout      (addr_readout),
        .addr_readout_valid(addr_readout_valid),
        .data_readout      (data_readout),
        .data_readout_valid(data_readout_valid),

        .fh_x    (fh_x),
        .fh_y    (fh_y),
        .fh_u    (fh_u),
        .fh_v    (fh_v),
        .fh_valid(fh_valid),
        .fh_done_proc(fh_done_proc), 
        .timestep_count(timestep_count),

        .axis_m_ready(axis_m_ready),
        .timer_count(timer_count),



        // debug registers

        .enable_count   (enable_count),
        .event_count   (event_count),
        .busy_count    (busy_count),
        .idle_count    (idle_count),
        .inference_count(inference_count),
        .layer_e1_count(layer_e1_count),
        .layer_e2_count(layer_e2_count),
        .layer_m1_count(layer_m1_count),
        .layer_m2_count(layer_m2_count),
        .layer_m3_count(layer_m3_count),
        .layer_m4_count(layer_m4_count),
        .layer_d1_count(layer_d1_count),
        .layer_h_count (layer_h_count),
        .layer_h_stall(layer_h_stall),

        .layer_e1_spike_count(layer_e1_spike_count),
        .layer_e2_spike_count(layer_e2_spike_count),
        .layer_m1_spike_count(layer_m1_spike_count),
        .layer_m2_spike_count(layer_m2_spike_count),
        .layer_m3_spike_count(layer_m3_spike_count),
        .layer_m4_spike_count(layer_m4_spike_count),
        .layer_d1_spike_count(layer_d1_spike_count)


    );

    // Instantiate the AXI4-Stream Master (which drives m_axis_*)
    // This master will send data TO the DMA (e.g., to an S2MM channel)
    flow_m_axis #(
        .C_AXIS_TDATA_WIDTH(C_AXIS_TDATA_WIDTH)
    ) m_inst (
        .aclk         (aclk),
        .aresetn      (aresetn),
        .m_axis_tdata (m_axis_tdata),
        .m_axis_tlast (m_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        //.m_axis_tready(1'b1),

        .fh_x    (fh_x),
        .fh_y    (fh_y),
        .fh_u    (fh_u),
        .fh_v    (fh_v),
        .fh_valid(fh_valid),
        .timestep_count(timestep_count),
        .fh_done_proc(fh_done_proc),
        .axis_m_ready(axis_m_ready)

    );






endmodule
