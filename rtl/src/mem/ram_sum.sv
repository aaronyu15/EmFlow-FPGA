`timescale 1ps / 1ps
import design_pkg::*;
`default_nettype none

module ram_sum (
    input wire clk,   // Clock 
    input wire rst_n, // Active Low Reset

    input  wire               en,
    input  wire               wea,         // Write Enable
    input  wire  [SUM_AWIDTH-1:0] addra,       // Write Address
    input  wire  [SUM_DWIDTH-1:0] dina,        // Data Input  
    input  wire  [SUM_AWIDTH-1:0] addrb,       // Write Address
    output logic [SUM_DWIDTH-1:0] doutb,       // Data Output
    output logic              doutb_valid

);


    xpm_memory_sdpram #(
        .ADDR_WIDTH_A           (SUM_AWIDTH),           // DECIMAL
        .ADDR_WIDTH_B           (SUM_AWIDTH),           // DECIMAL
        .AUTO_SLEEP_TIME        (0),                // DECIMAL
        .BYTE_WRITE_WIDTH_A     (SUM_DWIDTH),              // DECIMAL
        .CASCADE_HEIGHT         (0),                // DECIMAL
        .CLOCKING_MODE          ("common_clock"),   // String
        .ECC_BIT_RANGE          ("7:0"),            // String
        .ECC_MODE               ("no_ecc"),         // String
        .ECC_TYPE               ("none"),           // String
        .IGNORE_INIT_SYNTH      (0),                // DECIMAL
        .MEMORY_INIT_FILE       ("none"),           // String
        .MEMORY_INIT_PARAM      ("0"),              // String
        .MEMORY_OPTIMIZATION    ("true"),           // String
        .MEMORY_PRIMITIVE       ("ultra"),          // String
        .MEMORY_SIZE            (SUM_SIZE),          // DECIMAL
        .MESSAGE_CONTROL        (0),                // DECIMAL
        //.RAM_DECOMP             ("auto"),           // String
        .READ_DATA_WIDTH_B      (SUM_DWIDTH),              // DECIMAL
        .READ_LATENCY_B         (3),                // DECIMAL
        .READ_RESET_VALUE_B     ("0"),              // String
        .RST_MODE_A             ("SYNC"),           // String
        .RST_MODE_B             ("SYNC"),           // String
        .SIM_ASSERT_CHK         (0),                // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_EMBEDDED_CONSTRAINT(0),                // DECIMAL
        .USE_MEM_INIT           (1),                // DECIMAL
        .USE_MEM_INIT_MMI       (0),                // DECIMAL
        .WAKEUP_TIME            ("disable_sleep"),  // String
        .WRITE_DATA_WIDTH_A     (SUM_DWIDTH),              // DECIMAL
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

    // synthesis translate_off

    logic [SUM_DWIDTH-1:0] mem_debug[(1<<SUM_AWIDTH)-1:0];
    logic [SUM_WIDTH-1:0] mem_entries[2**SUM_AWIDTH][C_PCHANNELS];

    always @(posedge clk) begin : mem_debug_block
        if (en) begin
            if (wea) begin
                mem_debug[addra] <= dina;
            end
        end
    end : mem_debug_block

    always_comb begin
        for (int k = 0; k < 2 ** SUM_AWIDTH; k = k + 1) begin
            for (int j = 0; j < C_PCHANNELS; j = j + 1) begin
                mem_entries[k][j] = mem_debug[k][j*SUM_WIDTH+:SUM_WIDTH];
            end
        end
    end


    // synthesis translate_on
endmodule
