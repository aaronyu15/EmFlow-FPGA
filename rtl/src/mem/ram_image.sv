// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1ps/1ps
`default_nettype none
import design_pkg::*;

module ram_image #(

) (
    input wire clk,    // Clock 
    input wire mem_en, // Memory Enable

    input wire              wea,    // Write Enable
    input wire [IMG_AWIDTH-1:0] addra,  // Write Address
    input wire [IMG_DWIDTH-1:0] dina,   // Data Input  

    input wire     [IMG_AWIDTH-1:0] addrb,  // Read  Address
    output reg [IMG_DWIDTH-1:0] doutb,
    output reg              validb   // Data Output
);

    (* ram_style = "ultra" *)
    reg [IMG_DWIDTH-1:0] mem[(1<<IMG_AWIDTH)-1:0];  // Memory Declaration
    reg [IMG_DWIDTH-1:0] memreg;
    //reg [IMG_DWIDTH-1:0] mem_pipe_reg[NBPIPE-1:0];  // Pipelines for memory
    reg mem_en_pipe_reg;  // Pipelines for memory enable  

    integer i;

    initial begin
        for (i = 0; i < (1<<IMG_AWIDTH); i = i + 1) mem[i] = '0;
    end

    // RAM : Both READ and WRITE have a latency of one
    always @(posedge clk) begin
        if (mem_en) begin
            if (wea) mem[addra] <= dina;

            memreg <= mem[addrb];
        end
    end

    // Pipeline stages are more important with more cascade stages of uram. Since I only use 2 per image buffer,
    // I will try using just one pipeline stage for now.
    always @(posedge clk) begin
        mem_en_pipe_reg <= mem_en;
        if (mem_en_pipe_reg) begin
                doutb <= memreg;
                validb <= 1'b1;
        end else begin
                validb <= 1'b0;
        end
    end

endmodule
