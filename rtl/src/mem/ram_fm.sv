// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1ps/1ps
`default_nettype none

import design_pkg::*;
module ram_fm (
    input wire clk,  // Clock 
    input wire rst_n, // Active Low Reset

    input  wire              ena,
    input  wire              wea,    // Write Enable
    input  wire [FM_AWIDTH-1:0] addra,  // Write Address
    input  wire [FM_DWIDTH-1:0] dina,   // Data Input  

    input  wire              enb,
    input  wire [FM_AWIDTH-1:0] addrb,  // Read  Address
    output reg   [FM_DWIDTH-1:0] doutb
);

    (* ram_style = "block" *)
    reg [FM_DWIDTH-1:0] mem[(1<<FM_AWIDTH)-1:0];  // Memory Declaration
    reg [FM_DWIDTH-1:0] memreg;
    //reg [FM_DWIDTH-1:0] mem_pipe_reg[NBPIPE-1:0];  // Pipelines for memory
    reg mem_en_pipe_reg;  // Pipelines for memory enable  

    integer i;
    initial begin
        for (i = 0; i < (1 << FM_AWIDTH); i = i + 1) mem[i] = '0;
    end

    always @(posedge clk) begin
        if (ena) begin
            if (wea) mem[addra] <= dina;
        end
    end

    always @(posedge clk) begin
        if (enb) begin
            doutb <= mem[addrb];
        end
    end

endmodule
