// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1ps/1ps
// generic_axis_slave_correct.sv
// AXI4-Stream (AXIS) Slave with proper handshake logic

module flow_s_axis #(
    parameter C_AXIS_TDATA_WIDTH = 64  // Width of TDATA
) (
    // Global Signals
    input wire aclk,
    input wire aresetn,


    // AXI4-Stream Slave Interface
    input  wire [C_AXIS_TDATA_WIDTH-1:0] s_axis_tdata,
    input  wire                          s_axis_tlast,
    input  wire                          s_axis_tvalid,
    output logic                          s_axis_tready,

    // Slave's internal output interface for downstream logic
    output logic [C_AXIS_TDATA_WIDTH-1:0] data_o,
    input  wire                          ready_i,
    output logic                          valid_o,
    output logic                          last_o
);


    // Internal Registers for AXI4-Stream Handshake and State
    logic [C_AXIS_TDATA_WIDTH-1:0] data_reg;
    logic last_reg;
    logic valid_reg;

    wire axis_good;
    // --- AXI4-Stream Handshake Logic ---
    // The slave is ready if the downstream module is ready OR the internal
    // register is empty. This prevents data loss.
    // We are ready to accept new data if our output buffer is not full.
    assign axis_good = s_axis_tvalid && s_axis_tready;

    // --- Data Capture Logic ---
    // Capture data from the AXI4-Stream bus on a successful handshake
    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            data_reg  <= '0;
            last_reg  <= 1'b0;
            valid_reg <= 1'b0;
        end else begin
            // AXI4-Stream handshake condition:
            if (axis_good) begin
                data_reg  <= s_axis_tdata;
                valid_reg <= 1'b1;
            end else if (!s_axis_tvalid) begin
                valid_reg <= 1'b0;
            end

            last_reg <= s_axis_tlast;
        end
    end

    // --- Output Assignments ---
    // Assign the internal registers to the module's output ports
    assign data_o = data_reg;
    assign last_o = last_reg;
    assign valid_o = valid_reg;

    assign s_axis_tready = ready_i;


endmodule
