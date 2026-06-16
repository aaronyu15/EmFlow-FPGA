// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1ps/1ps
`default_nettype none

import design_pkg::*;
module ram_flow_head (
    input wire clk,  // Clock 
    input wire rst_n, // Active Low Reset

    input  wire              en,
    input  wire              wea,    // Write Enable
    input  wire [FH_AWIDTH-1:0] addra,  // Write Address
    input  wire [FH_DWIDTH-1:0] dina,   // Data Input  

    input  wire [FH_AWIDTH-1:0] addrb,  // Read  Address
    output reg   [FH_DWIDTH-1:0] doutb
);

    xpm_memory_sdpram #(
        .ADDR_WIDTH_A           (FH_AWIDTH),           // DECIMAL
        .ADDR_WIDTH_B           (FH_AWIDTH),           // DECIMAL
        .AUTO_SLEEP_TIME        (0),                // DECIMAL
        .BYTE_WRITE_WIDTH_A     (FH_DWIDTH),              // DECIMAL
        .CASCADE_HEIGHT         (0),                // DECIMAL
        .CLOCKING_MODE          ("common_clock"),   // String
        .ECC_BIT_RANGE          ("7:0"),            // String
        .ECC_MODE               ("no_ecc"),         // String
        .ECC_TYPE               ("none"),           // String
        .IGNORE_INIT_SYNTH      (0),                // DECIMAL
        .MEMORY_INIT_FILE       ("none"),           // String
        .MEMORY_INIT_PARAM      ("0"),              // String
        .MEMORY_OPTIMIZATION    ("true"),           // String
        .MEMORY_PRIMITIVE       ("block"),          // String
        .MEMORY_SIZE            (FH_SIZE),          // DECIMAL
        .MESSAGE_CONTROL        (0),                // DECIMAL
        //.RAM_DECOMP             ("auto"),           // String
        .READ_DATA_WIDTH_B      (FH_DWIDTH),              // DECIMAL
        .READ_LATENCY_B         (1),                // DECIMAL
        .READ_RESET_VALUE_B     ("0"),              // String
        .RST_MODE_A             ("SYNC"),           // String
        .RST_MODE_B             ("SYNC"),           // String
        .SIM_ASSERT_CHK         (0),                // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_EMBEDDED_CONSTRAINT(0),                // DECIMAL
        .USE_MEM_INIT           (1),                // DECIMAL
        .USE_MEM_INIT_MMI       (0),                // DECIMAL
        .WAKEUP_TIME            ("disable_sleep"),  // String
        .WRITE_DATA_WIDTH_A     (FH_DWIDTH),              // DECIMAL
        .WRITE_MODE_B           ("read_first"),     // String
        .WRITE_PROTECT          (1)                 // DECIMAL
    ) xpm_memory_sdpram_inst (
        .dbiterrb(),  // 1-bit output: Status signal to indicate double bit error occurrence
        // on the data output of port B.

        .doutb   (doutb),  // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
        .sbiterrb(),       // 1-bit output: Status signal to indicate single bit error occurrence
        // on the data output of port B.

        .addra(addra),  // ADDR_WIDTH_A-bit input: Address for port A write operations.
        .addrb(addrb),  // ADDR_WIDTH_B-bit input: Address for port B read operations.
        .clka (clk),    // 1-bit input: Clock signal for port A. Also clocks port B when
                        // parameter CLOCKING_MODE is "common_clock".

        .clkb(),  // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
        // "independent_clock". Unused when parameter CLOCKING_MODE is
        // "common_clock".

        .dina(dina),  // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
        .ena (en),    // 1-bit input: Memory enable signal for port A. Must be high on clock
                      // cycles when write operations are initiated. Pipelined internally.

        .enb(en),  // 1-bit input: Memory enable signal for port B. Must be high on clock
                   // cycles when read operations are initiated. Pipelined internally.

        .injectdbiterra(),  // 1-bit input: Controls double bit error injection on input data when
        // ECC enabled (Error injection capability is not available in
        // "decode_only" mode).

        .injectsbiterra(),  // 1-bit input: Controls single bit error injection on input data when
        // ECC enabled (Error injection capability is not available in
        // "decode_only" mode).

        .regceb(en),  // 1-bit input: Clock Enable for the last register stage on the output
        // data path.

        .rstb(!rst_n),  // 1-bit input: Reset signal for the final port B output register stage.
        // Synchronously resets output port doutb to the value specified by
        // parameter READ_RESET_VALUE_B.

        .sleep(),    // 1-bit input: sleep signal to enable the dynamic power saving feature.
        .wea  (wea)  // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
                     // for port A input data port dina. 1 bit wide when word-wide writes are
                     // used. In byte-wide write configurations, each bit controls the
                     // writing one byte of dina to address addra. For example, to
                     // synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
                     // is 32, wea would be 4'b0010.

    );


endmodule
