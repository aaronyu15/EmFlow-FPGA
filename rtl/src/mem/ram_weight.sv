// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps
`default_nettype none

import design_pkg::*;
// Simple synchronous single-port block RAM.
module ram_weight (
    input  wire              clk,
    input  wire              we,    // write enable
    input  wire [WEIGHT_AWIDTH-1:0] addr,
    input  wire [WEIGHT_DWIDTH-1:0] din,
    output logic [WEIGHT_DWIDTH-1:0] dout
);

    // Inference-friendly attribute for block RAM.
    (* ram_style = "block" *)
    logic [WEIGHT_DWIDTH-1:0] mem[(1<<WEIGHT_AWIDTH)-1:0];  
    
    always_ff @(posedge clk) begin
        if (we) begin
            mem[addr] <= din;
        end
        dout <= mem[addr];
    end


`ifdef SYNTHESIS
    initial begin
        $readmemh("weights.mem", mem);     
    end

`else
    initial begin
        $readmemh(WEIGHT_MEM_FILE, mem);     
    end

`endif

 
    //========================================================================
    //NETWORK STRUCTURE OVERVIEW
    //========================================================================
    //  Layer           Weight Shape       Stride  Pad Groups LIF Type
    //  ----------------------------------------------------------------------
    //  e1              8x1x3x3                 2    1      1 QuantizedLIF (spike_no_membrane)
    //  e2              8x8x3x3                 2    1      1 QuantizedLIF (spike_no_membrane)
    //  m1              16x8x3x3                2    1      1 QuantizedLIF
    //  m2              16x16x3x3               1    1      1 QuantizedLIF
    //  m3              16x16x3x3               1    1      1 QuantizedLIF
    //  m4              16x16x3x3               1    1      1 QuantizedLIF
    //  d1              8x16x3x3                1    1      1 QuantizedLIF (spike_no_membrane)
    //  flow_head       2x8x3x3                 1    1      1 — (no LIF)
    //
    // total number of weights: 1176 addresses * 9 * 8 bit
    // total number of M0 values: 98 addresses * 12 bit
    // total number of shift values: 98 addresses * 5 bit


endmodule
