`timescale 1ps / 1ps `default_nettype none

import design_pkg::*;

module flow_head (
    input wire clk,
    input wire rst_n,

    input  state_fh_t state_sel,
    input  wire       done_proc_in,
    output logic      done_proc_out,

    // feature map from the previous layer (8 channels)
    input wire       valid_spike[C_PCHANNELS],
    input wire       in_valid,

    // image buffer to filter only active pixels
    input  wire  [8:0] filter_x,
    input  wire  [8:0] filter_y,
    input  wire        filter_xy_valid,
    output logic       fh_ready,

    // output to AXIS M
    output logic [       8:0] out_x,
    output logic [       8:0] out_y,
    output logic [MEMB_I-1:0] out_u,
    output logic [MEMB_I-1:0] out_v,
    output logic              out_valid,

    input wire axis_m_ready

);

    logic done_proc_in_sticky;

    // 8 input channels, 2 output channels

    logic [8:0] filter_x_fifo;
    logic [8:0] filter_y_fifo;

    // feature map ram
    logic ram_fh_en;
    logic ram_fh_wea;  // Write Enable
    logic [FH_AWIDTH-1:0] ram_fh_addra;  // Write Address
    logic [FH_DWIDTH-1:0] ram_fh_dina;  // Data Input  

    logic [FH_AWIDTH-1:0] ram_fh_addrb;  // Read  Address
    logic [FH_DWIDTH-1:0] ram_fh_doutb;

    // fifo
    logic [FH_FIFO_DWIDTH-1:0] fifo_din;
    logic [FH_FIFO_DWIDTH-1:0] fifo_dout;

    logic fifo_rd_en;
    logic fifo_wr_en;
    logic fifo_empty;
    logic fifo_prog_full;

    state_fh_t state, state_next;

    //logic [8:0] filter_x_reg;
    //logic [8:0] filter_y_reg;
    //logic filter_xy_valid_reg;
    logic in_valid_reg;
    logic [C_PCHANNELS/2-1:0] valid_spike_packed;


    logic [8:0] x_rel;
    logic [8:0] y_rel;

    logic [8:0] u_rel;
    logic [8:0] r_rel;
    logic [8:0] d_rel;
    logic [8:0] l_rel;

    logic u_rel_valid;
    logic r_rel_valid;
    logic d_rel_valid;
    logic l_rel_valid;

    logic u_rel_valid_reg;
    logic r_rel_valid_reg;
    logic d_rel_valid_reg;
    logic l_rel_valid_reg;

    logic all_valid;
    logic update_pt;
    logic reset_weight_mask;

    logic [FH_AWIDTH-1:0] addr_q[5];


    logic [4:0] idx;
    logic [4:0] idx_d;
    logic [4:0] idx_step;
    logic [4:0] idx_step_d;

    logic u_eq;
    logic r_eq;
    logic d_eq;
    logic l_eq;

    typedef enum {
        FH_PROC_IDLE,
        FH_PROC_SAMPLE_FIFO,
        FH_PROC_CALC_REL,
        FH_PROC_CALC_TYPE,
        FH_PROC_STEP
    } state_run_fh_t;

    state_run_fh_t state_run;
    state_run_fh_t state_run_next;

    typedef enum {
        TYPE_1,
        TYPE_2A,
        TYPE_2B,
        TYPE_2C,
        TYPE_2D,
        TYPE_4A,
        TYPE_4B,
        TYPE_4C,
        TYPE_4D
    } type_evt_t;

    type_evt_t event_type;
    type_evt_t event_type_reg;

    // weights setup
    logic [WEIGHT_DWIDTH-1:0] weights_p[C_PCHANNELS]; 
    logic signed [WEIGHT_WIDTH-1:0] weights[C_PCHANNELS][9];
    logic signed [WEIGHT_WIDTH-1:0] weights_u[C_PCHANNELS/2][9];  // output channel 0
    logic signed [WEIGHT_WIDTH-1:0] weights_v[C_PCHANNELS/2][9];  // output channel 1
    logic [M0_WIDTH-1:0] m0[2];
    logic [SHIFT_WIDTH-1:0] shift[2];

    // weights pipeline
    logic weight_pt_update[9];  // u, v output channel, kernel

    logic weight_u_mask[C_PCHANNELS/2][9];  // output channel 0
    logic weight_v_mask[C_PCHANNELS/2][9];  // output channel 1

    logic signed [WEIGHT_WIDTH-1:0] weight_u_pt[C_PCHANNELS/2][9];  // output channel 0
    logic signed [WEIGHT_WIDTH-1:0] weight_v_pt[C_PCHANNELS/2][9];  // output channel 1

    logic signed [31:0] sum1_1u[8];
    logic signed [31:0] sum1_2u[8];
    logic signed [31:0] sum1_3u[8];

    logic signed [31:0] sum1_1v[8];
    logic signed [31:0] sum1_2v[8];
    logic signed [31:0] sum1_3v[8];

    logic signed [31:0] sum2_u[8];
    logic signed [31:0] sum2_v[8];

    logic signed [31:0] sum3_u[4];
    logic signed [31:0] sum3_v[4];

    logic signed [31:0] sum4_u[2];
    logic signed [31:0] sum4_v[2];

    logic signed [31:0] sum5_u;
    logic signed [31:0] sum5_v;

    logic signed [31:0] sum6_ums;
    logic signed [31:0] sum6_vms;

    logic [8:0] fh_x[10];
    logic [8:0] fh_y[10];
    logic fh_valid[10];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= FH_IDLE;
            state_run <= FH_PROC_IDLE;
        end else begin
            state <= state_next;
            state_run <= state_run_next;
        end
    end


    always_comb begin
        state_next = state;  // default to hold state
        case (state)
            FH_IDLE: begin
                case (state_sel)
                    FH_STORE: state_next = FH_STORE;
                    FH_RUN:   state_next = FH_RUN;
                    default:  state_next = FH_IDLE;
                endcase
            end
            FH_STORE: begin
                if (ram_fh_addra >= C_H * C_W) begin
                    state_next = FH_IDLE;
                end
            end
            FH_RUN: begin
                if (fifo_empty && done_proc_in_sticky) begin
                    state_next = FH_RESET_MEM;
                end
            end
            FH_RESET_MEM: begin
                if (ram_fh_addra >= C_H * C_W) begin
                    state_next = FH_IDLE;
                end
            end
            default: state_next = FH_IDLE;
        endcase

        fifo_rd_en = 0;
        state_run_next = state_run;

        case (state_run)
            FH_PROC_IDLE: begin
                if (!fifo_empty && axis_m_ready) begin
                    fifo_rd_en = 1;
                    state_run_next = FH_PROC_CALC_REL;
                end
            end
            FH_PROC_CALC_REL: begin
                state_run_next = FH_PROC_CALC_TYPE;
            end
            FH_PROC_CALC_TYPE: begin
                case (event_type_reg)
                    TYPE_1: begin
                        state_run_next = FH_PROC_IDLE;
                    end
                    TYPE_2A, TYPE_2B, TYPE_2C, TYPE_2D: begin
                        if (all_valid) begin  // two reads, go to proc step
                            state_run_next = FH_PROC_STEP;
                        end else begin
                            state_run_next = FH_PROC_IDLE;
                        end
                    end
                    TYPE_4A, TYPE_4B, TYPE_4C, TYPE_4D: begin  // four reads, go to proc step
                        state_run_next = FH_PROC_STEP;
                    end
                    default: state_run_next = FH_PROC_IDLE;
                endcase
            end
            FH_PROC_STEP: begin
                if (idx >= 3) state_run_next = FH_PROC_IDLE;
            end
            default: state_run_next = FH_PROC_IDLE;

        endcase
    end

    assign filter_x_fifo = fifo_dout[9+:9];
    assign filter_y_fifo = fifo_dout[0+:9];


    assign all_valid = u_rel_valid_reg && r_rel_valid_reg && d_rel_valid_reg && l_rel_valid_reg;


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            fh_ready   <= 0;
            fifo_wr_en <= 0;
            ram_fh_en  <= 1'b0;
            ram_fh_wea <= 0;
            done_proc_out <= 0;
        end else begin
            done_proc_out <= 0;
            fifo_wr_en <= 0;
            valid_spike_packed <= {valid_spike[7], valid_spike[6], valid_spike[5], valid_spike[4], valid_spike[3], valid_spike[2], valid_spike[1], valid_spike[0]};
            // if needed filter_x_reg <= filter_x;
            // if needed filter_y_reg <= filter_y;
            // if needed filter_xy_valid_reg <= filter_xy_valid;
            in_valid_reg <= in_valid;


            case (state)
                FH_IDLE: begin
                    ram_fh_en <= 1'b0;
                    ram_fh_wea <= 0;

                    ram_fh_addra <= 0;
                end
                FH_STORE: begin
                    ram_fh_en <= 1'b1;

                    ram_fh_wea <= in_valid_reg;
                    ram_fh_addra <= ram_fh_addra + ram_fh_wea;
                    ram_fh_dina <= valid_spike_packed;
                end
                FH_RUN: begin
                    ram_fh_en  <= 1'b1;

                    fh_ready   <= 1;

                    // store in fifo
                    fifo_din   <= {filter_x, filter_y};  // pack x, y, and valid spikes into one word
                    fifo_wr_en <= filter_xy_valid;
                    if (fifo_prog_full) begin
                        fh_ready <= 0;
                    end


                    if (fifo_empty && done_proc_in_sticky) begin
                        done_proc_out <= 1;
                    end
                end

                FH_RESET_MEM: begin
                    ram_fh_en <= 1'b1;
                    ram_fh_wea <= 1'b1;

                    ram_fh_addra <= ram_fh_addra + ram_fh_wea;
                    ram_fh_dina <= 0;
                end
                default: begin
                    ram_fh_en <= 1'b0;
                    ram_fh_wea <= 0;
                end
            endcase


        end
    end


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            idx <= 0;
            idx_d <= 0;
            idx_step <= 0;
            idx_step_d <= 0;
            update_pt <= 0;

            weight_pt_update <= '{default: 0};

            fh_x[0] <= 0;
            fh_y[0] <= 0;
            fh_valid[0] <= 0;
            done_proc_in_sticky <= 0;
        end else begin
            if (done_proc_in) done_proc_in_sticky <= 1;
            idx <= 0;
            idx_d <= 0;
            idx_step <= 0;
            idx_step_d <= 0;

            update_pt <= 0;
            reset_weight_mask <= 0;

            fh_valid[0] <= 0;

            case (state_run)
                FH_PROC_IDLE: begin
                    // read data from fifo
                    ram_fh_addrb <= 0;
                    if (fifo_empty) begin
                        if (done_proc_in_sticky) begin
                            done_proc_in_sticky <= 0;
                            fh_x[0] <= 0;
                            fh_y[0] <= 0;
                        end
                    end
                end
                FH_PROC_CALC_REL: begin
                    reset_weight_mask <= 1;
                    // three
                    event_type_reg <= event_type;

                    addr_q[0] <= d_rel * C_W + l_rel;
                    addr_q[1] <= d_rel * C_W + r_rel;
                    addr_q[2] <= u_rel * C_W + l_rel;
                    addr_q[3] <= u_rel * C_W + r_rel;
                    addr_q[4] <= y_rel * C_W + x_rel;  // center

                    u_rel_valid_reg <= u_rel_valid;
                    r_rel_valid_reg <= r_rel_valid;
                    d_rel_valid_reg <= d_rel_valid;
                    l_rel_valid_reg <= l_rel_valid;

                end
                FH_PROC_CALC_TYPE: begin
                    case (event_type_reg)
                        TYPE_1: begin
                            ram_fh_addrb <= addr_q[4];
                            update_pt <= 1;  // ehhhh
                            fh_x[0] <= filter_x_fifo;
                            fh_y[0] <= filter_y_fifo;
                            fh_valid[0] <= 1;
                        end
                        TYPE_2A, TYPE_2B, TYPE_2C, TYPE_2D: begin
                            if (all_valid) begin  // two reads, go to proc step
                                idx_step <= 3;
                                idx <= 0;  // start with top left, then skip to the rest
                            end else begin
                                ram_fh_addrb <= addr_q[4];  // only center pixel if all valid
                                update_pt <= 1;  // ehhhh
                                fh_x[0] <= filter_x_fifo;
                                fh_y[0] <= filter_y_fifo;
                                fh_valid[0] <= 1;
                            end
                        end
                        TYPE_4A, TYPE_4B, TYPE_4C, TYPE_4D: begin  // four reads, go to proc step
                            idx_step <= 1;
                            idx <= 0;
                        end
                    endcase
                end
                FH_PROC_STEP: begin
                    ram_fh_addrb <= addr_q[idx_d];
                    update_pt <= 1;
                    idx <= idx + idx_step_d;  // delay the idx update to give time for the big case statement below to capture correct idx
                    idx_d <= idx_d + idx_step;  // misnamed the variable but its too late to change it
                    idx_step <= idx_step;
                    idx_step_d <= idx_step;

                    if (state_run_next == FH_PROC_IDLE) begin
                        update_pt <= 0;  // reset idx for next event
                    end

                    if (idx + idx_step_d == 3) begin
                        fh_x[0] <= filter_x_fifo;
                        fh_y[0] <= filter_y_fifo;
                        fh_valid[0] <= 1;
                    end
                end

                default: begin

                end
            endcase

            // this is fine here since after the update is set, it is used to update the mask with fm readout data,
            // after which pt_update switches to update the next weight places
            weight_pt_update <= '{default: 0};

            // same operation for u,v , all 8 channels

            if (update_pt) begin
                case (event_type_reg)  // holy fuck
                    TYPE_1: begin
                        for (int k = 0; k < 9; k++) begin
                            weight_pt_update[k] <= 1;
                        end
                    end
                    TYPE_2A: begin
                        if (all_valid) begin
                            case (idx)
                                0: begin
                                    weight_pt_update[0] <= 1;
                                    weight_pt_update[1] <= 1;
                                    weight_pt_update[2] <= 1;

                                end
                                3: begin
                                    weight_pt_update[3] <= 1;
                                    weight_pt_update[4] <= 1;
                                    weight_pt_update[5] <= 1;
                                    weight_pt_update[6] <= 1;
                                    weight_pt_update[7] <= 1;
                                    weight_pt_update[8] <= 1;

                                end
                                default: begin
                                end
                            endcase
                        end else begin  // not all valid, update up weights
                            weight_pt_update[3] <= 1;
                            weight_pt_update[4] <= 1;
                            weight_pt_update[5] <= 1;
                            weight_pt_update[6] <= 1;
                            weight_pt_update[7] <= 1;
                            weight_pt_update[8] <= 1;
                        end
                    end
                    TYPE_2B: begin
                        if (all_valid) begin
                            case (idx)
                                0: begin
                                    weight_pt_update[0] <= 1;
                                    weight_pt_update[1] <= 1;
                                    weight_pt_update[3] <= 1;
                                    weight_pt_update[4] <= 1;
                                    weight_pt_update[6] <= 1;
                                    weight_pt_update[7] <= 1;

                                end
                                3: begin
                                    weight_pt_update[2] <= 1;
                                    weight_pt_update[5] <= 1;
                                    weight_pt_update[8] <= 1;

                                end
                                default: begin
                                end
                            endcase
                        end else begin  // not all valid, update left weights
                            weight_pt_update[0] <= 1;
                            weight_pt_update[1] <= 1;
                            weight_pt_update[3] <= 1;
                            weight_pt_update[4] <= 1;
                            weight_pt_update[6] <= 1;
                            weight_pt_update[7] <= 1;
                        end
                    end
                    TYPE_2C: begin
                        if (all_valid) begin
                            case (idx)
                                0: begin
                                    weight_pt_update[0] <= 1;
                                    weight_pt_update[1] <= 1;
                                    weight_pt_update[2] <= 1;
                                    weight_pt_update[3] <= 1;
                                    weight_pt_update[4] <= 1;
                                    weight_pt_update[5] <= 1;
                                end
                                3: begin
                                    weight_pt_update[6] <= 1;
                                    weight_pt_update[7] <= 1;
                                    weight_pt_update[8] <= 1;
                                end
                                default: begin
                                end
                            endcase
                        end else begin  // not all valid, update down weights
                            weight_pt_update[0] <= 1;
                            weight_pt_update[1] <= 1;
                            weight_pt_update[2] <= 1;
                            weight_pt_update[3] <= 1;
                            weight_pt_update[4] <= 1;
                            weight_pt_update[5] <= 1;
                        end
                    end
                    TYPE_2D: begin
                        if (all_valid) begin
                            case (idx)
                                0: begin
                                    weight_pt_update[0] <= 1;
                                    weight_pt_update[3] <= 1;
                                    weight_pt_update[6] <= 1;
                                end
                                3: begin
                                    weight_pt_update[1] <= 1;
                                    weight_pt_update[2] <= 1;
                                    weight_pt_update[4] <= 1;
                                    weight_pt_update[5] <= 1;
                                    weight_pt_update[7] <= 1;
                                    weight_pt_update[8] <= 1;
                                end
                                default: begin
                                end
                            endcase
                        end else begin  // not all valid, update right weights
                            weight_pt_update[0] <= 1;
                            weight_pt_update[1] <= 1;
                            weight_pt_update[2] <= 1;
                            weight_pt_update[3] <= 1;
                            weight_pt_update[4] <= 1;
                            weight_pt_update[5] <= 1;
                        end
                    end
                    TYPE_4A: begin
                        case (idx)
                            0: begin
                                weight_pt_update[0] <= 1;
                                weight_pt_update[1] <= 1;
                                weight_pt_update[3] <= 1;
                                weight_pt_update[4] <= 1;
                            end
                            1: begin
                                if (r_rel_valid_reg) begin
                                    weight_pt_update[2] <= 1;
                                    weight_pt_update[5] <= 1;
                                end
                            end
                            2: begin
                                if (u_rel_valid_reg) begin
                                    weight_pt_update[6] <= 1;
                                    weight_pt_update[7] <= 1;
                                end
                            end
                            3: begin
                                if (r_rel_valid_reg && u_rel_valid_reg) begin
                                    weight_pt_update[8] <= 1;
                                end
                            end
                            default: begin
                            end
                        endcase
                    end
                    TYPE_4B: begin
                        case (idx)
                            0: begin
                                if (l_rel_valid_reg) begin
                                    weight_pt_update[0] <= 1;
                                    weight_pt_update[3] <= 1;
                                end
                            end
                            1: begin
                                weight_pt_update[1] <= 1;
                                weight_pt_update[2] <= 1;
                                weight_pt_update[4] <= 1;
                                weight_pt_update[5] <= 1;
                            end
                            2: begin
                                if (l_rel_valid_reg && u_rel_valid_reg) begin
                                    weight_pt_update[6] <= 1;
                                end
                            end
                            3: begin
                                if (u_rel_valid_reg) begin
                                    weight_pt_update[7] <= 1;
                                    weight_pt_update[8] <= 1;
                                end
                            end
                            default: begin
                            end
                        endcase
                    end
                    TYPE_4C: begin
                        case (idx)
                            0: begin
                                if (l_rel_valid_reg && d_rel_valid_reg) begin
                                    weight_pt_update[0] <= 1;
                                end
                            end
                            1: begin
                                if (d_rel_valid_reg) begin
                                    weight_pt_update[1] <= 1;
                                    weight_pt_update[2] <= 1;
                                end
                            end
                            2: begin
                                if (l_rel_valid_reg) begin
                                    weight_pt_update[3] <= 1;
                                    weight_pt_update[6] <= 1;
                                end
                            end
                            3: begin
                                weight_pt_update[4] <= 1;
                                weight_pt_update[5] <= 1;
                                weight_pt_update[7] <= 1;
                                weight_pt_update[8] <= 1;
                            end
                            default: begin
                            end
                        endcase
                    end
                    TYPE_4D: begin
                        case (idx)
                            0: begin
                                if (d_rel_valid_reg) begin
                                    weight_pt_update[0] <= 1;
                                    weight_pt_update[1] <= 1;
                                end
                            end
                            1: begin
                                if (r_rel_valid_reg && d_rel_valid_reg) begin
                                    weight_pt_update[2] <= 1;
                                end
                            end
                            2: begin
                                weight_pt_update[3] <= 1;
                                weight_pt_update[4] <= 1;
                                weight_pt_update[6] <= 1;
                                weight_pt_update[7] <= 1;
                            end
                            3: begin
                                if (r_rel_valid_reg) begin
                                    weight_pt_update[5] <= 1;
                                    weight_pt_update[8] <= 1;
                                end
                            end
                            default: begin
                            end
                        endcase
                    end
                    default: begin
                        weight_pt_update <= '{default: 0};
                    end
                endcase
            end
        end

        // weight_pt_update
        fh_x[1] <= fh_x[0];
        fh_y[1] <= fh_y[0];
        fh_valid[1] <= fh_valid[0];

        // update mask based on pt_update, mask is the feature map readout
        for (int ic = 0; ic < C_PCHANNELS/2; ic++) begin
            for (int k = 0; k < 9; k++) begin
                weight_u_mask[ic][k] <= weight_pt_update[k] ? ram_fh_doutb[ic] : weight_u_mask[ic][k];
                weight_v_mask[ic][k] <= weight_pt_update[k] ? ram_fh_doutb[ic] : weight_v_mask[ic][k];
            end
        end
        fh_x[2] <= fh_x[1];
        fh_y[2] <= fh_y[1];
        fh_valid[2] <= fh_valid[1];

        // update weights for pipeline based on masked values (masked by feature map)
        for (int ic = 0; ic < C_PCHANNELS/2; ic++) begin
            for (int k = 0; k < 9; k++) begin
                weight_u_pt[ic][k] <= weight_u_mask[ic][k] ? weights_u[ic][k] : 0;
                weight_v_pt[ic][k] <= weight_v_mask[ic][k] ? weights_v[ic][k] : 0;
            end
        end
        fh_x[3] <= fh_x[2];
        fh_y[3] <= fh_y[2];
        fh_valid[3] <= fh_valid[2];

        // p1
        fh_x[4] <= fh_x[3];
        fh_y[4] <= fh_y[3];
        fh_valid[4] <= fh_valid[3];

        // p2
        fh_x[5] <= fh_x[4];
        fh_y[5] <= fh_y[4];
        fh_valid[5] <= fh_valid[4];

        // p3
        fh_x[6] <= fh_x[5];
        fh_y[6] <= fh_y[5];
        fh_valid[6] <= fh_valid[5];

        // p4
        fh_x[7] <= fh_x[6];
        fh_y[7] <= fh_y[6];
        fh_valid[7] <= fh_valid[6];

        // p5
        fh_x[8] <= fh_x[7];
        fh_y[8] <= fh_y[7];
        fh_valid[8] <= fh_valid[7];

        // p6
        fh_x[9] <= fh_x[8];
        fh_y[9] <= fh_y[8];
        fh_valid[9] <= fh_valid[8];

        if (reset_weight_mask) begin  // prevent carryover
            weight_u_mask <= '{default: 0};
            weight_v_mask <= '{default: 0};
        end
    end

    always_comb begin
        u_rel = (filter_y_fifo + 1) >> 3;  // divide by 8
        r_rel = (filter_x_fifo + 1) >> 3;  // divide by 8
        d_rel = (filter_y_fifo - 1) >> 3;  // divide by 8
        l_rel = (filter_x_fifo - 1) >> 3;  // divide by 8

        x_rel = filter_x_fifo >> 3;  // divide by 8
        y_rel = filter_y_fifo >> 3;  // divide by 8

        u_eq  = (u_rel == y_rel);
        r_eq  = (r_rel == x_rel);
        d_eq  = (d_rel == y_rel);
        l_eq  = (l_rel == x_rel);

        // type 1
        // 111
        // 111
        // 111

        // type 2A    // type 2B    // type 2C    // type 2D
        // 111        // 112        // 111        // 122
        // 222        // 112        // 111        // 122
        // 222        // 112        // 222        // 122

        // type 4A    // type 4B    // type 4C    // type 4D
        // 112        // 122        // 122        // 112
        // 112        // 122        // 344        // 334
        // 334        // 344        // 344        // 334

        //  q0  d  q1
        //   l  x  r
        //  q2  u  q3

        // type 1: idx = 0, idx < 1, idx + 1
        // type 2: idx = 0, idx < 4, idx + 3
        // type 4: idx = 0, idx < 4, idx + 1

        // literal edge cases: if any are invalid, take the middle pixel only. Works for type 1 and type 2
        // but that doesnt work on an edge that crosses a boundary like in type 4...

        case ({
            u_eq, r_eq, d_eq, l_eq
        })
            4'b1111: event_type = TYPE_1;

            4'b1101: event_type = TYPE_2A;
            4'b1011: event_type = TYPE_2B;
            4'b0111: event_type = TYPE_2C;
            4'b1110: event_type = TYPE_2D;

            4'b0011: event_type = TYPE_4A;  // also applies to bottom right corner of individual 8x8 boxes + of global image
            4'b0110: event_type = TYPE_4B;  // also applies to bottom left corner  of individual 8x8 boxes + of global image
            4'b1100: event_type = TYPE_4C;  // also applies to top left corner     of individual 8x8 boxes + of global image
            4'b1001: event_type = TYPE_4D;  // also applies to top right corner    of individual 8x8 boxes + of global image

            // 4'b0000: not physically possible

            // 4'b0001: // not possible
            // 4'b0010: // not possible
            // 4'b0100: // not possible
            // 4'b1000: // not possible

            // 4'b1010: // not possible
            // 4'b0101: // not possible

            default: event_type = TYPE_1;  // treat as type 1 if invalid
        endcase

        u_rel_valid = u_rel < C_H;
        r_rel_valid = r_rel < C_W;
        d_rel_valid = d_rel < C_H;
        l_rel_valid = l_rel < C_W;

    end

    ram_flow_head ram_flow_head_inst (
        .clk  (clk),
        .rst_n(rst_n),

        .en   (ram_fh_en),
        .wea  (ram_fh_wea),
        .addra(ram_fh_addra),
        .dina (ram_fh_dina),

        .addrb(ram_fh_addrb),
        .doutb(ram_fh_doutb)

    );


`ifdef SYNTHESIS
    initial begin
        $readmemh("flow_head_weights.mem", weights_p);
        $readmemh("flow_head_m0.mem", m0);
        $readmemh("flow_head_shift.mem", shift);
    end
`else
    initial begin
        $readmemh(FH_WEIGHT_MEM_FILE, weights_p);
        $readmemh(FH_M0_MEM_FILE, m0);
        $readmemh(FH_SHIFT_MEM_FILE, shift);
    end

`endif

    // reformating variables
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            for (int j = 0; j < 9; j++) begin
                weights[i][j] = weights_p[i][j*WEIGHT_WIDTH+:WEIGHT_WIDTH];
            end
        end

        for (int ic = 0; ic < 8; ic = ic + 1) begin
            for (int j = 0; j < 9; j++) begin
                weights_u[ic][j] = weights[2*ic][j];
                weights_v[ic][j] = weights[2*ic+1][j];
            end
        end
    end

    // main processing pipeline

    always_ff @(posedge clk) begin
        // spacial - p1
        for (int i = 0; i < 8; i++) begin : channel
            sum1_1u[i] <= weight_u_pt[i][0] + weight_u_pt[i][1] + weight_u_pt[i][2];
            sum1_2u[i] <= weight_u_pt[i][3] + weight_u_pt[i][4] + weight_u_pt[i][5];
            sum1_3u[i] <= weight_u_pt[i][6] + weight_u_pt[i][7] + weight_u_pt[i][8];

            sum1_1v[i] <= weight_v_pt[i][0] + weight_v_pt[i][1] + weight_v_pt[i][2];
            sum1_2v[i] <= weight_v_pt[i][3] + weight_v_pt[i][4] + weight_v_pt[i][5];
            sum1_3v[i] <= weight_v_pt[i][6] + weight_v_pt[i][7] + weight_v_pt[i][8];
        end

        // spacial - p2
        for (int i = 0; i < 8; i++) begin
            sum2_u[i] <= sum1_1u[i] + sum1_2u[i] + sum1_3u[i];
            sum2_v[i] <= sum1_1v[i] + sum1_2v[i] + sum1_3v[i];
        end

        // channel - p3
        for (int i = 0; i < 4; i++) begin
            sum3_u[i] <= sum2_u[2*i] + sum2_u[2*i+1];
            sum3_v[i] <= sum2_v[2*i] + sum2_v[2*i+1];
        end

        // channel -p4
        for (int i = 0; i < 2; i++) begin
            sum4_u[i] <= sum3_u[2*i] + sum3_u[2*i+1];
            sum4_v[i] <= sum3_v[2*i] + sum3_v[2*i+1];
        end

        // channel - p5
        sum5_u <= sum4_u[0] + sum4_u[1];
        sum5_v <= sum4_v[0] + sum4_v[1];

        // m0 and shift - p6
        sum6_ums <= (sum5_u * $signed({1'b0, m0[0]})) >>> shift[0];
        sum6_vms <= (sum5_v * $signed({1'b0, m0[1]})) >>> shift[1];


        // output pack - p7
        out_u <= sum6_ums;
        out_v <= sum6_vms;
        out_x <= fh_x[9];
        out_y <= fh_y[9];
        out_valid <= (sum6_ums != 0 || sum6_vms != 0) ? fh_valid[9] : 0; // Ignore 0 outputs

    end

    // fifo for filter events


    // xpm_fifo_sync: Synchronous FIFO
    // Xilinx Parameterized Macro, version 2024.1

    xpm_fifo_sync #(
        .CASCADE_HEIGHT     (0),                          // DECIMAL
        .DOUT_RESET_VALUE   ("0"),                        // String
        .ECC_MODE           ("no_ecc"),                   // String
        //.EN_SIM_ASSERT_ERR  ("warning"),                  // String
        .FIFO_MEMORY_TYPE   ("auto"),                     // String
        .FIFO_READ_LATENCY  (1),                          // DECIMAL
        .FIFO_WRITE_DEPTH   (FH_FIFO_DEPTH),              // DECIMAL
        .FULL_RESET_VALUE   (0),                          // DECIMAL
        .PROG_EMPTY_THRESH  (10),                         // DECIMAL
        .PROG_FULL_THRESH   (50),                         // DECIMAL
        .RD_DATA_COUNT_WIDTH($clog2(FH_FIFO_DEPTH) + 1),  // DECIMAL
        .READ_DATA_WIDTH    (FH_FIFO_DWIDTH),             // DECIMAL
        .READ_MODE          ("std"),                      // String
        .SIM_ASSERT_CHK     (1),                          // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_ADV_FEATURES   ("0707"),                     // String
        .WAKEUP_TIME        (0),                          // DECIMAL
        .WRITE_DATA_WIDTH   (FH_FIFO_DWIDTH),             // DECIMAL
        .WR_DATA_COUNT_WIDTH($clog2(FH_FIFO_DEPTH) + 1)   // DECIMAL
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

        .rst(~rst_n),  // 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
        // unstable at the time of applying reset, but reset must be released only
        // after the clock(s) is/are stable.

        .sleep(),  // 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
        // block is in power saving mode.

        .wr_clk(clk),  // 1-bit input: Write clock: Used for write operation. wr_clk must be a
        // free running clock.

        .wr_en(fifo_wr_en)  // 1-bit input: Write Enable: If the FIFO is not full, asserting this
        // signal causes data (on din) to be written to the FIFO Must be held
        // active-low when rst or wr_rst_busy or rd_rst_busy is active high

    );

    // End of xpm_fifo_sync_inst instantiation



endmodule
