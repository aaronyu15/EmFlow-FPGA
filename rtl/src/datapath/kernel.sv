// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1ps / 1ps 
`default_nettype none

import design_pkg::*;

module kernel (
    input  wire  clk,
    input  wire  rst_n,
    output logic ready,
    input  wire  kernel_en,
    input  wire  sum_ready,

    input wire [ 8:0] dim,
    input wire [ 1:0] stride,
    input wire [K_WIDTH*9-1:0] weight_in,

    // Data interfaces
    input wire [8:0] x,        // Input data for LIF neuron
    input wire [8:0] y,        // Input data for LIF neuron
    input wire       xy_valid, // Indicates that data_in is valid

    output logic        [8:0] x_out,
    output logic        [8:0] y_out,
    output logic signed [K_WIDTH-1:0] kv,
    output logic              xy_out_valid,

    output logic [8:0] y_line,
    output logic [8:0] x_line,

    input wire done_proc_in,
    output logic done_proc_out

);
    // synthesis translate_off
    logic [17:0] yx_concat;
    assign yx_concat = {y, x};

    logic [17:0] yx_out_concat;
    assign yx_out_concat = {y_out, x_out};
    // synthesis translate_on

    logic [K_WIDTH*9-1:0] weight_reg;
    logic signed [K_WIDTH-1:0] weight[9];

    logic [8:0] x_reg, y_reg;
    logic xy_valid_reg;

    logic [8:0] xk[9];
    logic [8:0] yk[9];
    logic signed [K_WIDTH-1:0] kk[9];

    logic [4:0] idx;
    logic [4:0] max_idx;
    logic done_proc_in_d;

    typedef enum {
        IDLE,
        SEQ_1,
        SEQ_2,
        SEQ_2_WAIT
    } state_t;

    typedef enum {
        CENTER,
        EDGE_X,
        EDGE_Y,
        CORNER
    } stride_2_t;

    state_t state, state_next;
    stride_2_t stride_2_type;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            weight_reg <= 8'b0;
            x_reg <= 9'b0;
            y_reg <= 9'b0;
            xy_valid_reg <= 1'b0;
        end else begin
            weight_reg <= weight_in;  // Register the weight for use in computation
            x_reg <= x;
            y_reg <= y;
            xy_valid_reg <= xy_valid;
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= state_next;
        end
    end


    always_comb begin
        state_next = state;
        ready = 1'b1;

        case (state)
            IDLE: begin
                if (xy_valid_reg && kernel_en) begin
                    state_next = stride == 2'b01 ? SEQ_1 : SEQ_2;
                    ready = 1'b0;
                end
            end
            SEQ_1: begin
                ready = 1'b0;
                if (idx >= max_idx) begin
                    state_next = IDLE;
                end
            end
            SEQ_2: begin
                ready = 1'b0;
                if (idx >= max_idx && sum_ready) begin
                    state_next = SEQ_2_WAIT;
                end
            end
            SEQ_2_WAIT: begin // a dummy wait state
                ready = 1'b0;
                state_next = IDLE;
            end
            default: state_next = IDLE;
        endcase
    end




    // Kernel weights
    // 0 1 2
    // 3 4 5
    // 6 7 8

    always_comb begin
        for (int i = 0; i < 9; i++) begin
            weight[i] = $signed(weight_reg[i*K_WIDTH+:K_WIDTH]);  // Extract each K_WIDTH-bit weight from the input
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            idx <= 0;
            xy_out_valid <= 1'b0;
            max_idx <= 0;
            y_line <= 0;
            x_line <= 0;
        end else begin
            xy_out_valid <= 1'b0;
            y_line <= y_reg;
            x_line <= x_reg;
            // to match latency of x/y_line
            done_proc_in_d <= done_proc_in;
            done_proc_out <= done_proc_in_d;
            case (state)
                IDLE: begin
                    idx <= 0;
                    if (state_next == SEQ_2) begin
                        case (stride_2_type)
                            CENTER: begin
                                max_idx <= 0;
                                idx <= 0;
                            end
                            EDGE_Y: begin
                                max_idx <= 2;
                                idx <= 1;
                            end
                            EDGE_X: begin
                                max_idx <= 4;
                                idx <= 3;
                            end
                            CORNER: begin
                                max_idx <= 8;
                                idx <= 5;
                            end
                        endcase
                    end else if (state_next == SEQ_1) begin
                        max_idx <= 8;
                    end
                end
                SEQ_1: begin
                    x_out <= xk[idx];
                    y_out <= yk[idx];
                    kv <= kk[idx];
                    xy_out_valid <= 1'b1;

                    // 1 padding
                    if ((xk[idx] > (dim - 1)) || (yk[idx] > (dim - 1))) xy_out_valid <= 1'b0;

                    idx <= idx + 1;
                end
                SEQ_2: begin
                    // stride 2
                    if (sum_ready) begin // this is used in layer e1 to buffer the write/read swap
                        x_out <= xk[idx] >> 1;
                        y_out <= yk[idx] >> 1;
                        kv <= kk[idx];
                        xy_out_valid <= 1'b1;

                        // 1 padding
                        if ((xk[idx] > (dim - 1)) || (yk[idx] > (dim - 1))) xy_out_valid <= 1'b0;

                        // weird
                        idx <= idx + 1;
                    end

                end
            endcase
        end
    end

    // 0 1 2
    // 3 4 5
    // 6 7 8

    always_ff @(posedge clk) begin : window
        if (xy_valid_reg && kernel_en) begin
            xk[0] <= x_reg;  // center
            yk[0] <= y_reg;  // center
            kk[0] <= weight[4];  // center

            xk[1] <= x_reg;  // edge y
            yk[1] <= y_reg - 1;  // edge y
            kk[1] <= weight[7];  // edge y

            xk[2] <= x_reg;  // edge y
            yk[2] <= y_reg + 1;  // edge y
            kk[2] <= weight[1];  // edge y

            xk[3] <= x_reg - 1;  // edge x
            yk[3] <= y_reg;  // edge x
            kk[3] <= weight[5];  // edge x

            xk[4] <= x_reg + 1;  // edge x
            yk[4] <= y_reg;  // edge x
            kk[4] <= weight[3];  // edge x

            xk[5] <= x_reg - 1;  // corner
            yk[5] <= y_reg - 1;  // corner
            kk[5] <= weight[8];  // corner

            xk[6] <= x_reg + 1;  // corner
            yk[6] <= y_reg - 1;  // corner
            kk[6] <= weight[6];  // corner

            xk[7] <= x_reg - 1;  // corner
            yk[7] <= y_reg + 1;  // corner
            kk[7] <= weight[2];  // corner

            xk[8] <= x_reg + 1;  // corner
            yk[8] <= y_reg + 1;  // corner
            kk[8] <= weight[0];  // corner

        end
    end

    always_comb begin : stride_2
        case ({
            x_reg[0], y_reg[0]
        })
            2'b00: begin
                stride_2_type = CENTER;  // idx 4
            end
            2'b01: begin
                stride_2_type = EDGE_Y;  // idx 1, 7
            end
            2'b10: begin

                stride_2_type = EDGE_X;  // idx 3, 5
            end
            2'b11: begin
                stride_2_type = CORNER;  // idx 0, 2, 6, 8
            end
        endcase
    end




endmodule
