// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1ps / 1ps

module flow_wrapper #(
    parameter C_AXIS_TDATA_WIDTH   = 64,  // Match TDATA_WIDTH of DMA's AXIS interface
    parameter C_AXILITE_ADDR_WIDTH = 32,
    parameter C_AXILITE_DATA_WIDTH = 32
) (
    // Global Signals from Block Design
    input wire aclk,
    input wire aresetn,

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

    output wire  [C_AXIS_TDATA_WIDTH-1:0] m_axis_tdata,
    output wire                           m_axis_tlast,
    output wire                           m_axis_tvalid,
    input  wire                          m_axis_tready,

    input  wire [C_AXIS_TDATA_WIDTH-1:0] s_axis_tdata,
    input  wire                          s_axis_tlast,
    input  wire                          s_axis_tvalid,
    output wire                           s_axis_tready
);

    flow_top inst (
        .aclk   (aclk),
        .aresetn(aresetn),

        // AXI4-Lite Interface
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

        // AXIS Master Interface
        .m_axis_tdata (m_axis_tdata),
        .m_axis_tlast (m_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),

        // AXIS Slave Interface
        .s_axis_tdata (s_axis_tdata),
        .s_axis_tlast (s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready)
    );
    

endmodule
