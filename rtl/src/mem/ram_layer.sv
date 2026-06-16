`timescale 1ns / 1ps
`default_nettype none
import design_pkg::*;
// Simple synchronous single-port block RAM.
module ram_layer (
    input  wire              clk,
    input  wire [INSTR_AWIDTH-1:0] addr,
    output logic [INSTR_DWIDTH-1:0] instr1,
    output logic [INSTR_DWIDTH-1:0] instr2
);

    // Inference-friendly attribute for block RAM.
    (* ram_style = "distributed" *) logic [INSTR_DWIDTH-1:0] mem[(1<<INSTR_AWIDTH)-1:0];  // Memory Declaration

    always_ff @(posedge clk) begin
        instr1 <= mem[addr];
        instr2 <= mem[addr+1];
    end

`ifdef SYNTHESIS
    initial begin : init_block
        $readmemh("instruct.mem", mem);
    end
`else
    initial begin : init_block
        $readmemh(INSTR_MEM_FILE, mem);
    end
`endif



endmodule
