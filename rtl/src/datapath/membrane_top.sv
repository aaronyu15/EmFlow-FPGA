`timescale 1ps / 1ps `default_nettype none

import design_pkg::*;
module membrane_top (
    input  wire             clk,
    input  wire             rst_n,
    input  state_membrane_t state_sel,
    output logic            membrane_top_ready,

    input wire [    MEMB_AWIDTH-1:0] mem_offset,
    input wire [THRESHOLD_WIDTH-1:0] threshold,

    input wire        [       8:0] x,
    input wire        [       8:0] y,
    input wire signed [MEMB_I-1:0] I       [C_PCHANNELS],
    input wire                     xy_valid,

    output logic [8:0] x_spike,
    output logic [8:0] y_spike,
    output logic       valid_spike[C_PCHANNELS],
    output logic       valid_out,

    input  wire  done_proc_in,
    output logic done_proc_out
);
    // synthesis translate_off
    logic [17:0] yx_concat;
    assign yx_concat = {y, x};
    // synthesis translate_on

    state_membrane_t state, state_next;
    logic [THRESHOLD_WIDTH-1:0] threshold_reg;

    logic en;
    logic wea;
    logic [MEMB_AWIDTH-1:0] addra;
    logic [MEMB_DWIDTH-1:0] dina;

    logic [MEMB_AWIDTH-1:0] addrb;
    logic [MEMB_AWIDTH-1:0] addrb_d[4];
    logic [MEMB_DWIDTH-1:0] doutb;
    // synthesis translate_off
    logic [MEMB_WIDTH-1:0] doutb_memb[C_PCHANNELS];
    always_comb begin
        for (int i = 0; i < C_PCHANNELS; i++) begin
            doutb_memb[i] = doutb[i*MEMB_WIDTH+:MEMB_WIDTH];
        end
    end
    // synthesis translate_on
    logic doutb_valid;

    logic [8:0] x_reg;
    logic [8:0] y_reg;
    logic signed [MEMB_I-1:0] I_reg[5][C_PCHANNELS];
    logic xy_valid_reg;
    logic xy_valid_reg_d[5];

    logic signed [15:0] update_mem[C_PCHANNELS];
    logic signed [15:0] new_mem[C_PCHANNELS];
    logic [8:0] x_reg_d[5];
    logic [8:0] y_reg_d[5];

    logic [MEMB_AWIDTH-1:0] total_offset;

    logic rst_done;
    logic update_done;
    logic [11:0] update_count;

    logic done_proc_in_sticky;

    // synthesis translate_off



    // synthesis translate_on

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            total_offset <= 0;
        end else begin
            total_offset <= mem_offset;  // 1600 = 40*40, the size of one channel's membrane memory
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= MEM_IDLE;
        end else begin
            state <= state_next;
        end
    end

    always_comb begin
        state_next = state;
        membrane_top_ready = 1'b0;
        case (state)
            MEM_IDLE: begin
                membrane_top_ready = 1'b1;
                case (state_sel)
                    MEM_IDLE:      state_next = MEM_IDLE;
                    MEM_THRESHOLD: state_next = MEM_THRESHOLD;
                    MEM_RESET:     state_next = MEM_PRE_RESET;
                    MEM_LIF:    state_next = MEM_LIF;
                    default:       state_next = MEM_IDLE;
                endcase
            end
            MEM_THRESHOLD: begin
                if (done_proc_in_sticky) begin
                    membrane_top_ready = 1'b1;
                    if (state_sel == MEM_IDLE) state_next = MEM_IDLE;
                end
            end
            MEM_PRE_RESET: begin
                state_next = MEM_RESET;
            end
            MEM_RESET: begin
                if (rst_done) state_next = MEM_IDLE;
            end
            MEM_LIF: begin
                if (update_done) begin
                    membrane_top_ready = 1'b1;
                    if (state_sel == MEM_RESET) state_next = MEM_PRE_RESET;
                    else if (state_sel == MEM_IDLE) state_next = MEM_IDLE;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            en <= 1'b0;
            wea <= 1'b0;
            addra <= 'b0;
            dina <= 'b0;

            addrb <= 'b0;
            rst_done <= 1'b0;
            valid_spike <= '{default: 1'b0};
            xy_valid_reg_d <= '{default: 1'b0};
            xy_valid_reg <= 1'b0;

            update_done <= 1'b0;
            update_count <= 0;

            done_proc_out <= 1'b0;
            done_proc_in_sticky <= 1'b0;
        end else begin
            if (done_proc_in) done_proc_in_sticky <= 1'b1;
            done_proc_out <= 1'b0;

            rst_done <= 1'b0;
            valid_spike <= '{default: 1'b0};
            threshold_reg <= threshold;
            x_reg <= x;
            y_reg <= y;
            xy_valid_reg <= xy_valid;

            xy_valid_reg_d[0] <= xy_valid_reg;
            x_reg_d[0] <= x_reg;
            y_reg_d[0] <= y_reg;
            // pipeline
            for (int i = 0; i < C_PCHANNELS; i++) begin
                if (xy_valid) begin
                    I_reg[0][i] <= I[i];
                end else begin
                    I_reg[0][i] <= 0;
                end
                I_reg[1][i] <= I_reg[0][i];
                I_reg[2][i] <= I_reg[1][i];
                I_reg[3][i] <= I_reg[2][i];
                I_reg[4][i] <= I_reg[3][i];
            end

            for (int i = 1; i < 5; i = i + 1) begin
                x_reg_d[i] <= x_reg_d[i-1];
                y_reg_d[i] <= y_reg_d[i-1];
                xy_valid_reg_d[i] <= xy_valid_reg_d[i-1];
            end

            addrb_d[0] <= addrb;
            addrb_d[1] <= addrb_d[0];
            addrb_d[2] <= addrb_d[1];
            addrb_d[3] <= addrb_d[2];

            // for threshold mode
            x_spike <= x_reg;
            y_spike <= y_reg;

            // for flow head
            valid_out <= xy_valid_reg;

            case (state)
                MEM_IDLE: begin
                    en <= 1'b0;
                    wea <= 1'b0;
                    valid_spike <= '{default: 1'b0};
                    update_done <= 1'b0;
                    update_count <= 0;
                    done_proc_in_sticky <= 1'b0;
                end
                MEM_THRESHOLD: begin

                    for (int i = 0; i < C_PCHANNELS; i = i + 1) begin
                        if (xy_valid_reg && I_reg[0][i] > $signed({1'b0, threshold_reg})) valid_spike[i] <= 1'b1;
                    end

                    done_proc_out <= done_proc_in_sticky;
                end
                MEM_PRE_RESET: begin
                    en <= 1'b1;
                    wea <= 1'b1;
                    addra <= 0;
                    dina <= 'b0;
                end
                MEM_RESET: begin
                    en <= 1'b1;
                    wea <= 1'b1;
                    addra <= addra + 1;
                    dina <= 'b0;

                    if (addra >= C_W * C_H * 4) rst_done <= 1'b1;
                end
                MEM_LIF: begin
                    en <= 1'b1;

                    // one
                    addrb <= x_reg + y_reg * C_W + total_offset;

                    // two

                    // three -- data availabel
                    for (int i = 0; i < C_PCHANNELS; i++) begin
                        update_mem[i] <= I_reg[4][i] + ($signed(doutb[i*MEMB_WIDTH+:MEMB_WIDTH]) >>> 1);  // leak for update
                    end

                    // four
                    for (int i = 0; i < C_PCHANNELS; i++) begin
                        if (update_mem[i] > $signed({1'b0, threshold_reg})) begin
                            dina[i*MEMB_WIDTH+:MEMB_WIDTH] <= 0;
                            valid_spike[i] <= 1'b1;
                        end else begin
                            dina[i*MEMB_WIDTH+:MEMB_WIDTH] <= update_mem[i];
                            valid_spike[i] <= 1'b0;
                        end
                    end
                    x_spike <= x_reg_d[4];
                    y_spike <= y_reg_d[4];
                    wea <= xy_valid_reg_d[4];
                    addra <= addrb_d[3];

                    update_count <= update_count + xy_valid_reg_d[4];

                    if (update_count >= C_W * C_H) begin
                        update_done   <= 1'b1;
                        done_proc_out <= 1'b1;
                    end
                end
            endcase

        end
    end


    ram_membrane ram_mem_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .en         (en),
        .wea        (wea),
        .addra      (addra),
        .dina       (dina),
        .addrb      (addrb),
        .doutb      (doutb),
        .doutb_valid(doutb_valid)
    );

endmodule
