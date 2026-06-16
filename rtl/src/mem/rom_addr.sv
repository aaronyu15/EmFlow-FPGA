// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1ps/1ps
`default_nettype none

module rom_addr_40 (
    input wire clk,
    input wire rst_n,
    input wire [12:0] addr,
    output logic [8:0] x,
    output logic [8:0] y
);

    (* rom_style = "block" *)
    logic [17:0] mem[2**11-1:0]; //2k x 18

    always_ff @(posedge clk) begin
        {y, x} <= mem[addr];
    end

    initial begin 
        logic [8:0] xi, yi;
        for (int i = 0; i < 40*40; i++) begin
            xi = i % 40;
            yi = i / 40;
            mem[i] = {yi, xi};
        end

    end

endmodule

module rom_addr_80 (
    input wire clk,
    input wire rst_n,
    input wire [12:0] addr,
    output logic [8:0] x,
    output logic [8:0] y
);

    (* rom_style = "block" *)
    logic [17:0] mem[2**13-1:0]; // 8k x 18

    always_ff @(posedge clk) begin
        if (!rst_n) begin
        end else begin
            {y, x} <= mem[addr];
        end
    end

    initial begin 
        logic [8:0] xi, yi;
        for (int i = 0; i < 80*80; i++) begin
            xi = i % 80;
            yi = i / 80;
            mem[i] = {yi, xi};
        end

    end

endmodule