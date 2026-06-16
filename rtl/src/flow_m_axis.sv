// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1ps / 1ps `default_nettype none

import design_pkg::*;

module flow_m_axis #(
    parameter C_AXIS_TDATA_WIDTH = 64  // Width of TDATA
) (
    // Global Signals
    input wire aclk,
    input wire aresetn,


    // AXI4-Stream Master Interface
    output logic [C_AXIS_TDATA_WIDTH-1:0] m_axis_tdata,
    output logic                          m_axis_tlast,
    output logic                          m_axis_tvalid,
    input  wire                           m_axis_tready,

    // Master's internal input interface for upstream logic
    input  wire  [       8:0] fh_x,
    input  wire  [       8:0] fh_y,
    input  wire  [MEMB_I-1:0] fh_u,
    input  wire  [MEMB_I-1:0] fh_v,
    input  wire               fh_valid,
    input  wire  [       3:0] timestep_count,
    input  wire               fh_done_proc,
    output logic              axis_m_ready
);

    localparam int PACKET_WIDTH = 4 + 9 + 9 + MEMB_I + MEMB_I;
    localparam int DONE_PROC_IDX = C_AXIS_TDATA_WIDTH - 1;  // Place fh_done_proc at the MSB of the packet
    localparam int PACKET_SPARE = C_AXIS_TDATA_WIDTH - PACKET_WIDTH - 1;


    // Internal registers for AXI4-Stream outputs
    logic [C_AXIS_TDATA_WIDTH-1:0] tdata_reg;
    logic tlast_reg;
    logic tvalid_reg;

    logic [C_AXIS_TDATA_WIDTH-1:0] packet;  // 36 bits total, tdata width is 64, so upper is left empty
    logic packet_valid;

    typedef enum {
        IDLE,
        DATA_READ,
        DATA_OUTPUT
    } state_t;
    logic [C_AXIS_TDATA_WIDTH-1:0] data_i;
    logic ready_o;
    logic valid_i;
    logic last_i;

    state_t current_state, next_state;

    logic [C_AXIS_TDATA_WIDTH-1:0] fifo_din;
    logic fifo_wr_en;
    logic fifo_rd_en;
    logic [C_AXIS_TDATA_WIDTH-1:0] fifo_dout;
    logic fifo_empty;
    logic fifo_prog_full;

    // AXI4-Stream outputs are driven by the registers
    assign m_axis_tdata = tdata_reg;
    assign m_axis_tlast = tlast_reg;
    assign m_axis_tvalid = tvalid_reg;

    assign ready_o = m_axis_tready;

    always @(posedge aclk) begin
        current_state <= next_state;

        if (!aresetn) begin
            current_state <= IDLE;
        end
    end

    always @(*) begin
        // Default next state is the current state
        next_state = current_state;
        fifo_rd_en = 1'b0;  // Default to not reading from FIFO

        case (current_state)
            IDLE: begin
                if (!fifo_empty && m_axis_tready) begin  // keep it simple
                    fifo_rd_en = 1;
                    next_state = DATA_READ;
                end
            end

            DATA_READ: begin
                next_state = DATA_OUTPUT;
            end

            DATA_OUTPUT: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;  // Fallback to IDLE on unexpected state
        endcase
    end

    always @(posedge aclk) begin
        case (current_state)
            IDLE: begin
                tvalid_reg <= 1'b0;
                tlast_reg  <= 1'b0;
            end

            DATA_READ: begin
                tdata_reg  <= fifo_dout & {1'b0, {PACKET_SPARE{1'b0}}, {PACKET_WIDTH{1'b1}}};  // Mask to ensure only valid bits are used
                tvalid_reg <= 1'b1;
                tlast_reg  <= fifo_dout[DONE_PROC_IDX];
            end

            DATA_OUTPUT: begin
                tvalid_reg <= 1'b0;
                tlast_reg  <= 1'b0;
            end

            default: begin
                tvalid_reg <= 1'b0;  // Indicate no valid data to send
                tlast_reg  <= 0;
            end

        endcase

        if (!aresetn) begin
            tlast_reg  <= 1'b0;
            tvalid_reg <= 1'b0;  // Indicate valid data is ready to be sent
        end
    end




    // xpm_fifo_sync: Synchronous FIFO
    // Xilinx Parameterized Macro, version 2024.1
    localparam int MAXIS_FIFO_DEPTH = 32;
    localparam int MAXIS_FIFO_DWIDTH = 64;

    assign axis_m_ready = ~fifo_prog_full;  // Backpressure when FIFO is almost full

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            fifo_wr_en   <= 1'b0;
            packet_valid <= 1'b0;
        end else begin
            packet <= {fh_done_proc, {PACKET_SPARE{1'b0}}, timestep_count, fh_x, fh_y, fh_u, fh_v};
            packet_valid <= fh_valid | fh_done_proc;  // Valid when either data is valid or done_proc is asserted

            fifo_din <= packet;
            if (~fifo_prog_full) begin
                fifo_wr_en <= packet_valid;
            end else begin
                fifo_wr_en <= 1'b0;  // Stop writing if FIFO is almost full
            end
        end
    end


    xpm_fifo_sync #(
        .CASCADE_HEIGHT     (0),                             // DECIMAL
        .DOUT_RESET_VALUE   ("0"),                           // String
        .ECC_MODE           ("no_ecc"),                      // String
        //.EN_SIM_ASSERT_ERR  ("warning"),                  // String
        .FIFO_MEMORY_TYPE   ("auto"),                        // String
        .FIFO_READ_LATENCY  (1),                             // DECIMAL
        .FIFO_WRITE_DEPTH   (MAXIS_FIFO_DEPTH),              // DECIMAL
        .FULL_RESET_VALUE   (0),                             // DECIMAL
        .PROG_EMPTY_THRESH  (5),                             // DECIMAL
        .PROG_FULL_THRESH   (13),                            // DECIMAL
        .RD_DATA_COUNT_WIDTH($clog2(MAXIS_FIFO_DEPTH) + 1),  // DECIMAL
        .READ_DATA_WIDTH    (MAXIS_FIFO_DWIDTH),             // DECIMAL
        .READ_MODE          ("std"),                         // String
        .SIM_ASSERT_CHK     (1),                             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES   ("0707"),                        // String
        .WAKEUP_TIME        (0),                             // DECIMAL
        .WRITE_DATA_WIDTH   (MAXIS_FIFO_DWIDTH),             // DECIMAL
        .WR_DATA_COUNT_WIDTH($clog2(MAXIS_FIFO_DEPTH) + 1)   // DECIMAL
    ) xpm_fifo_sync_inst (
        .almost_empty(),  // 1-bit output: Almost Empty : When asserted, this signal indicates that
        // only one more read can be performed before the FIFO goes to empty.

        .almost_full(),  // 1-bit output: Almost Full: When asserted, this signal indicates that
        // only one more write can be performed before the FIFO is full.

        .data_valid(),  // 1-bit output: Read Data Valid: When asserted, this signal indicates
        // that valid data is available on the output bus (dout).

        .dbiterr(),  // 1-bit output: Double Bit Error: Indicates that the ECC decoder detected
        // a double-bit error and data in the FIFO core is corrupted.

        .dout(fifo_dout),  // READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
        // when reading the FIFO.

        .empty(fifo_empty),  // 1-bit output: Empty Flag: When asserted, this signal indicates that the
        // FIFO is empty. Read requests are ignored when the FIFO is empty,
        // initiating a read while empty is not destructive to the FIFO.

        .full(),  // 1-bit output: Full Flag: When asserted, this signal indicates that the
        // FIFO is full. Write requests are ignored when the FIFO is full,
        // initiating a write when the FIFO is full is not destructive to the
        // contents of the FIFO.

        .overflow(),  // 1-bit output: Overflow: This signal indicates that a write request
        // (wren) during the prior clock cycle was rejected, because the FIFO is
        // full. Overflowing the FIFO is not destructive to the contents of the
        // FIFO.

        .prog_empty(),  // 1-bit output: Programmable Empty: This signal is asserted when the
        // number of words in the FIFO is less than or equal to the programmable
        // empty threshold value. It is de-asserted when the number of words in
        // the FIFO exceeds the programmable empty threshold value.

        .prog_full(fifo_prog_full),  // 1-bit output: Programmable Full: This signal is asserted when the
        // number of words in the FIFO is greater than or equal to the
        // programmable full threshold value. It is de-asserted when the number of
        // words in the FIFO is less than the programmable full threshold value.

        .rd_data_count(),  // RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates the
        // number of words read from the FIFO.

        .rd_rst_busy(),  // 1-bit output: Read Reset Busy: Active-High indicator that the FIFO read
        // domain is currently in a reset state.

        .sbiterr(),  // 1-bit output: Single Bit Error: Indicates that the ECC decoder detected
        // and fixed a single-bit error.

        .underflow(),  // 1-bit output: Underflow: Indicates that the read request (rd_en) during
        // the previous clock cycle was rejected because the FIFO is empty. Under
        // flowing the FIFO is not destructive to the FIFO.

        .wr_ack(),  // 1-bit output: Write Acknowledge: This signal indicates that a write
        // request (wr_en) during the prior clock cycle is succeeded.

        .wr_data_count(),  // WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
        // the number of words written into the FIFO.

        .wr_rst_busy(),  // 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
        // write domain is currently in a reset state.

        .din(fifo_din),  // WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
        // writing the FIFO.

        .injectdbiterr(),  // 1-bit input: Double Bit Error Injection: Injects a double bit error if
        // the ECC feature is used on block RAMs or UltraRAM macros.

        .injectsbiterr(),  // 1-bit input: Single Bit Error Injection: Injects a single bit error if
        // the ECC feature is used on block RAMs or UltraRAM macros.

        .rd_en(fifo_rd_en),  // 1-bit input: Read Enable: If the FIFO is not empty, asserting this
        // signal causes data (on dout) to be read from the FIFO. Must be held
        // active-low when rd_rst_busy is active high.

        .rst(~aresetn),  // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
        // unstable at the time of applying reset, but reset must be released only
        // after the clock(s) is/are stable.

        .sleep(),  // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
        // block is in power saving mode.

        .wr_clk(aclk),  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
        // free running clock.

        .wr_en(fifo_wr_en)  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
        // signal causes data (on din) to be written to the FIFO Must be held
        // active-low when rst or wr_rst_busy or rd_rst_busy is active high

    );





endmodule
