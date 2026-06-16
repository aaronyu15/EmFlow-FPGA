`timescale 1ps / 1ps

import design_pkg::*;
module q_scale (
    input wire clk,
    input wire rst_n,

    input wire        [          8:0] sum_x,
    input wire        [          8:0] sum_y,
    input wire signed [SUM_WIDTH-1:0] sum_in   [C_PCHANNELS],
    input wire                        sum_valid,

    input wire [   M0_WIDTH-1:0] m0   [C_PCHANNELS],
    input wire [SHIFT_WIDTH-1:0] shift[C_PCHANNELS],

    output logic        [       8:0] q_x,
    output logic        [       8:0] q_y,
    output logic signed [MEMB_I-1:0] q_out      [C_PCHANNELS],
    output logic                     q_out_valid,

    input wire done_proc_in,
    output logic done_proc_out
);

    logic signed [31:0] intermed_q[C_PCHANNELS];
    logic signed [31:0] intermed_q_d[C_PCHANNELS];
    logic signed [8:0] shift_q[C_PCHANNELS];
    logic [8:0] x_d[3];
    logic [8:0] y_d[3];
    logic valid_d[3];

    logic [M0_WIDTH-1:0] m0_reg[C_PCHANNELS];
    logic [SHIFT_WIDTH-1:0] shift_reg[C_PCHANNELS];


    logic done_proc_in_d[3];

    genvar i;
    generate
        for (i = 0; i < C_PCHANNELS; i++) begin
            always @(posedge clk) begin


                // Perform multiplication and shifting
                intermed_q[i] <= sum_in[i] * $signed({1'b0, m0_reg[i]});
                intermed_q_d[i] <= intermed_q[i];
                shift_q[i] <= intermed_q_d[i] >>> shift_reg[i];

            end
        end
    endgenerate


    // pipeline coordinates
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            valid_d <= '{default: 1'b0};
            q_out_valid <= 0;
        end else begin
            x_d[0] <= sum_x;
            y_d[0] <= sum_y;
            valid_d[0] <= sum_valid;

            for (int j = 1; j < 3; j = j + 1) begin
                x_d[j] <= x_d[j-1];
                y_d[j] <= y_d[j-1];
                valid_d[j] <= valid_d[j-1];
            end

            q_x <= x_d[2];
            q_y <= y_d[2];
            for (int j = 0; j < C_PCHANNELS; j = j + 1) begin
                q_out[j] <= $signed(shift_q[j][MEMB_I-1:0]);
            end
            q_out_valid <= valid_d[2];

            for (int j = 0; j < C_PCHANNELS; j = j + 1) begin
                // these will be constant during computations
                m0_reg[j] <= m0[j];
                shift_reg[j] <= shift[j];
            end


            done_proc_in_d[0] <= done_proc_in;
            for (int j = 1; j < 3; j = j + 1) begin
                done_proc_in_d[j] <= done_proc_in_d[j-1];
            end
            done_proc_out <= done_proc_in_d[2];

        end
    end



endmodule
