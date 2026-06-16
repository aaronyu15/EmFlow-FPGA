`timescale 1ps / 1ps `default_nettype none

import design_pkg::*;

module fm_reader (
    input wire clk,
    input wire rst_n,

    input  wire  start,
    input  wire  fm_source_sel,
    output logic fm_reader_ready,
    input wire       [$clog2(C_NUM_FM)-1:0] fm_rd_sel,  // select 0 - 15, from control fsm

    input wire [8:0] dim,

    // for image buffer, up to 3200 (320x10) entries
    output logic [FMRD_AWIDTH-1:0] s0_addr,
    output logic                   s0_addr_valid,
    input  wire  [FMRD_DWIDTH-1:0] s0_dout,
    input  wire                    s0_dout_valid,

    // for feature maps, up to 800 (160x5) entries
    output logic [FMRD_AWIDTH-1:0] s1_addr,
    output logic                   s1_addr_valid,
    input  wire  [FMRD_DWIDTH-1:0] s1_dout,
    input  wire                    s1_dout_valid,

    output logic [8:0] x,
    output logic [8:0] y,
    output logic       xy_valid,

    input wire kernel_ready,

    output logic done_proc_out,

    // debug register
    input wire enable_count,
    input wire enable_count_pulse,
    output logic [31:0] event_count
);

    typedef enum {
        IDLE,
        READWORD,
        WAIT_RESP,
        DECODE,
        VALID_OUT,
        CHECK_ANY,
        WAIT,
        LAST_WORD
    } state_t;

    state_t state, state_next;

    logic [FMRD_AWIDTH-1:0] addr;
    logic valid;
    logic rd_zero;

    logic [FMRD_DWIDTH-1:0] data;
    logic [FMRD_DWIDTH-1:0] data_reg;
    logic data_valid;

    logic [8:0] word_count;
    logic [8:0] line_count;

    logic [8:0] max_word_count;
    logic [8:0] max_line_count;

    logic [5:0] idx;
    logic any;
    logic [2:0] word_width_bits;

    logic [5:0] last_word_count;


    always_comb begin : mux
        idx = encoder(data_reg, any);
        case (dim)
            320: begin
                max_word_count = 10;
            end
            160: begin
                max_word_count = 5;
            end
            80: begin
                max_word_count = 3;
            end
            40: begin
                max_word_count = 2;
            end
            default: begin
                max_word_count = 0;
            end
        endcase

        max_line_count  = dim;
        word_width_bits = 5;

    end

    always_comb begin : mux_2port
        s0_addr = (fm_source_sel == 0) ? addr : 0;
        s0_addr_valid = (fm_source_sel == 0) ? valid : 1'b0;

        s1_addr = (fm_source_sel == 1) ? addr : 0;
        s1_addr_valid = (fm_source_sel == 1) ? valid : 1'b0;

        data = (fm_source_sel == 0) ? s0_dout : s1_dout;
        data_valid = (fm_source_sel == 0) ? s0_dout_valid : s1_dout_valid;
    end



    always_ff @(posedge clk) begin
        if (enable_count) begin
            if (fm_source_sel == 0 && state == VALID_OUT) begin
                event_count <= event_count + 1; // this is unique events for the input feature map
            end
        end

        if (!rst_n || enable_count_pulse) begin
            event_count <= 0;
        end
    end


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= state_next;
        end
    end


    always_comb begin : state_update
        state_next = state;
        fm_reader_ready = 0;

        case (state)
            IDLE: begin
                fm_reader_ready = 1;
                if (start) begin
                    state_next = READWORD;
                    fm_reader_ready = 0;
                end
            end
            READWORD: begin
                state_next = WAIT_RESP;
            end
            WAIT_RESP: begin
                if (data_valid) state_next = CHECK_ANY;
            end
            CHECK_ANY: begin
                if (any && kernel_ready) state_next = VALID_OUT;
                else if (any && !kernel_ready) state_next = CHECK_ANY;
                else if (line_count >= max_line_count - 1 && word_count >= max_word_count - 1) state_next = LAST_WORD;
                else state_next = READWORD;
            end
            VALID_OUT: begin
                state_next = CHECK_ANY;
            end

            LAST_WORD: begin
                state_next = IDLE;
            end
        endcase
    end


    // For now, just return the address as data for testing.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            addr <= 'b0;
            valid <= 1'b0;

            xy_valid <= 1'b0;
            word_count <= 9'b0;
            line_count <= 9'b0;
            rd_zero <= 1'b0;

            done_proc_out <= 1'b0;
        end else begin
            xy_valid <= 1'b0;
            done_proc_out <= 1'b0;

            case (state)
                IDLE: begin
                    addr <= 'b0;
                    valid <= 1'b0;

                    word_count <= 9'b0;
                    line_count <= 9'b0;
                    rd_zero <= 1'b0;
                    x <= 0;
                    y <= 0;
                end
                READWORD: begin
                    addr <= addr + rd_zero;
                    valid <= 1'b1;
                    rd_zero <= 1'b1;
                end
                WAIT_RESP: begin
                    valid <= 1'b0;
                    if (data_valid) begin
                        data_reg <= data;
                    end
                end
                CHECK_ANY: begin
                    if (state_next == READWORD) begin
                        word_count <= word_count + 1;
                        if (word_count >= max_word_count - 1) begin
                            word_count <= 0;
                            line_count <= line_count + 1;
                        end
                    end
                    if (state_next == VALID_OUT) begin
                        x <= idx + (word_count << word_width_bits);
                        y <= line_count;
                        xy_valid <= 1'b1;
                        data_reg <= data_reg ^ (1 << idx);
                    end
                end
                VALID_OUT: begin
                end
                LAST_WORD: begin
                    done_proc_out <= 1'b1;
                end

            endcase

        end
    end


    // synthesis translate_off

    logic [31:0] fm_count [C_PCHANNELS];
    logic [$clog2(C_NUM_FM)-1:0] fm_rd_sel_d;


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            fm_count <= '{default: 32'b0};
        end else begin
            fm_rd_sel_d <= fm_rd_sel;

            if (state == VALID_OUT) begin
                fm_count[fm_rd_sel] <= fm_count[fm_rd_sel] + 1;
            end

            if(state == IDLE) begin
                fm_count <= '{default: 32'b0};
            end
        end
    end

    // synthesis translate_on






    function automatic logic [5:0] encoder(input logic [31:0] v, output logic a);
        logic [5:0] idx;
        a   = 1'b0;
        idx = '0;
        for (int k = 0; k < 32; k++) begin
            if (!a && v[k]) begin
                idx = k;
                a   = 1'b1;
            end
        end
        return idx;
    endfunction

endmodule
