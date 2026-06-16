// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps `default_nettype none

import design_pkg::*;

module flow_snn (
    input wire clk,
    input wire rst_n,

    // Control plane
    input  wire  en,
    input  wire  run,
    output logic busy,

    output logic read_reset,
    output logic [IMG_AWIDTH-1:0] img_buff_addr,
    output logic                  img_buff_addr_valid,
    input  wire  [IMG_DWIDTH-1:0] img_buff_data,
    input  wire                   img_buff_data_valid,

    output logic [       8:0] fh_x,
    output logic [       8:0] fh_y,
    output logic [MEMB_I-1:0] fh_u,
    output logic [MEMB_I-1:0] fh_v,
    output logic              fh_valid,
    output logic             fh_done_proc_out,
    output logic [3:0] timestep_count,

    input wire axis_m_ready,

    input  wire         enable_count,
    output logic [31:0] event_count,
    output logic [31:0] busy_count,
    output logic [31:0] idle_count,
    output logic [31:0] inference_count,
    output logic [31:0] layer_e1_count,
    output logic [31:0] layer_e2_count,
    output logic [31:0] layer_m1_count,
    output logic [31:0] layer_m2_count,
    output logic [31:0] layer_m3_count,
    output logic [31:0] layer_m4_count,
    output logic [31:0] layer_d1_count,
    output logic [31:0] layer_h_count,
    output logic [31:0] layer_h_stall,

    output logic [31:0] layer_e1_spike_count,
    output logic [31:0] layer_e2_spike_count,
    output logic [31:0] layer_m1_spike_count,
    output logic [31:0] layer_m2_spike_count,
    output logic [31:0] layer_m3_spike_count,
    output logic [31:0] layer_m4_spike_count,
    output logic [31:0] layer_d1_spike_count
);

    logic enable_count_d;
    logic enable_count_pulse;

    logic all_ready;

    logic fm_top_ready_reg;
    logic fm_reader_ready_reg;
    logic sum_ready_reg;
    logic membrane_top_ready_reg;

    logic fm_top_ready;
    logic fm_reader_ready;
    logic sum_ready;
    logic membrane_top_ready;
    logic fh_ready;

    logic fm_reader_done_proc_out;
    logic kernel_done_proc_out[C_PCHANNELS];
    logic sum_done_proc_out;
    logic q_scale_done_proc_out;
    logic membrane_top_done_proc_out;


    state_top_t state, next_state;

    layer_name_t layer_count;
    // Instruction reader
    logic [35:0] instr1, instr2;
    instr_word1_t instr1_reg;
    instr_word2_t instr2_reg;
    logic [INSTR_AWIDTH-1:0] instr_addr;

    // Weight reader
    logic [WEIGHT_AWIDTH-1:0] weight_addr;
    logic [WEIGHT_DWIDTH-1:0] weight_data;
    logic [WEIGHT_AWIDTH-1:0] max_weight_addr;
    logic [7:0] weight_count;
    logic weight_sample;

    logic [$clog2(C_PCHANNELS)-1:0] kernel_select;
    logic [WEIGHT_DWIDTH-1:0] k_weight[C_PCHANNELS];
    logic [M0_WIDTH-1:0] k_m0[C_PCHANNELS];
    logic [SHIFT_WIDTH-1:0] k_shift[C_PCHANNELS];
    logic [THRESHOLD_WIDTH-1:0] k_threshold;

    logic reset_mst;
    logic load_next_mst;

    logic run_layer;
    logic layer_idle;

    // layer control signals
    state_layer_t state_layer, next_state_layer;

    state_fm_t fm_state_sel;
    state_sum_t sum_state_sel;
    state_membrane_t membrane_state_sel;
    logic [1:0] kernel_stride;
    logic fm_reader_source_sel;
    logic fm_reader_start;

    // fm top
    logic [8:0] fm_x;
    logic [8:0] fm_y;
    logic fm_xy_valid[C_PCHANNELS];

    logic [$clog2(C_NUM_FM)-1:0] fm_rd_sel;
    logic [FM_AWIDTH-1:0] fm_addr;
    logic fm_addr_valid;
    logic [FM_DWIDTH-1:0] fm_dout;
    logic fm_dout_valid;


    // fm reader 
    logic [8:0] fm_evt_x;
    logic [8:0] fm_evt_y;
    logic fm_evt_valid;

    // kernel
    logic kernel_en[C_PCHANNELS];
    logic [8:0] kernel_x[C_PCHANNELS];
    logic [8:0] kernel_y[C_PCHANNELS];
    logic signed [K_WIDTH-1:0] kernel_kv[C_PCHANNELS];
    logic kernel_valid[C_PCHANNELS];
    logic kernel_ready[C_PCHANNELS];

    logic [8:0] kernel_y_line[C_PCHANNELS];
    logic [8:0] kernel_x_line[C_PCHANNELS];


    // sum
    logic [8:0] sum_x;
    logic [8:0] sum_y;
    logic signed [SUM_WIDTH-1:0] sum_out[C_PCHANNELS];
    logic sum_valid;
    logic readout_done;

    // q_scale
    logic [8:0] q_x;
    logic [8:0] q_y;
    logic signed [MEMB_I-1:0] q_out[C_PCHANNELS];
    logic q_out_valid;

    // mem top
    logic [8:0] mem_x_spike;
    logic [8:0] mem_y_spike;
    logic mem_valid_spike[C_PCHANNELS];
    logic mem_valid_out;

    logic fh_xy_valid[C_PCHANNELS];
    logic fh_in_valid;
    state_fh_t fh_state_sel;

    logic [8:0] filter_x;
    logic [8:0] filter_y;
    logic filter_xy_valid;
    logic any_mem_valid_spike;

    assign any_mem_valid_spike = mem_valid_spike[0] | mem_valid_spike[1] | mem_valid_spike[2] | mem_valid_spike[3] | mem_valid_spike[4] | mem_valid_spike[5] | mem_valid_spike[6] | mem_valid_spike[7] | mem_valid_spike[8] | mem_valid_spike[9] | mem_valid_spike[10] | mem_valid_spike[11] | mem_valid_spike[12] | mem_valid_spike[13] | mem_valid_spike[14] | mem_valid_spike[15];

    assign all_ready = fm_top_ready_reg && fm_reader_ready && sum_ready && membrane_top_ready_reg;

    always_ff @(posedge clk) begin
        fm_top_ready_reg <= fm_top_ready;
        fm_reader_ready_reg <= fm_reader_ready;
        sum_ready_reg <= sum_ready;
        membrane_top_ready_reg <= membrane_top_ready;
    end


    ram_layer ram_layer_inst (
        .clk   (clk),
        .addr  (instr_addr),
        .instr1(instr1),
        .instr2(instr2)
    );

    ram_weight ram_weight_inst (
        .clk (clk),
        .we  (),
        .addr(weight_addr),
        .din (),
        .dout(weight_data)

    );

    ram_mst ram_mst_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .load_next_mst(load_next_mst),
        .reset_mst    (reset_mst),
        .num_out_ch   (instr1_reg.out_c),
        .m0           (k_m0),
        .shift        (k_shift),
        .threshold    (k_threshold)
    );


    // debug registers

    assign enable_count_pulse = enable_count && !enable_count_d; // pulse on assertion

    always_ff @(posedge clk) begin
        enable_count_d <= enable_count;

        if (enable_count) begin
            busy_count  <= busy ? busy_count + 1 : busy_count;
            idle_count  <= !busy ? idle_count + 1 : idle_count;

            inference_count <= (fh_done_proc_out && layer_count == LAYER_HEAD) ? inference_count + 1 : inference_count;

            case (layer_count)
                LAYER_E1:   if (busy) layer_e1_count <= layer_e1_count + 1;
                LAYER_E2:   layer_e2_count <= layer_e2_count + 1;
                LAYER_M1:   layer_m1_count <= layer_m1_count + 1;
                LAYER_M2:   layer_m2_count <= layer_m2_count + 1;
                LAYER_M3:   layer_m3_count <= layer_m3_count + 1;
                LAYER_M4:   layer_m4_count <= layer_m4_count + 1;
                LAYER_D1:   layer_d1_count <= layer_d1_count + 1;
                LAYER_HEAD: begin
                    layer_h_count <= layer_h_count + 1;
                    layer_h_stall <= (axis_m_ready == 1'b0) ? layer_h_stall + 1 : layer_h_stall;
                end
                default: begin
                end
            endcase

            case (layer_count)
                LAYER_E1:   if(any_mem_valid_spike) layer_e1_spike_count <= layer_e1_spike_count + 1;
                LAYER_E2:   if(any_mem_valid_spike) layer_e2_spike_count <= layer_e2_spike_count + 1;
                LAYER_M1:   if(any_mem_valid_spike) layer_m1_spike_count <= layer_m1_spike_count + 1;
                LAYER_M2:   if(any_mem_valid_spike) layer_m2_spike_count <= layer_m2_spike_count + 1;
                LAYER_M3:   if(any_mem_valid_spike) layer_m3_spike_count <= layer_m3_spike_count + 1;
                LAYER_M4:   if(any_mem_valid_spike) layer_m4_spike_count <= layer_m4_spike_count + 1;
                LAYER_D1:   if(any_mem_valid_spike) layer_d1_spike_count <= layer_d1_spike_count + 1;
                default: begin
                end
            endcase
        end

        if (!rst_n || enable_count_pulse) begin
            busy_count <= 0;
            idle_count <= 0;
            inference_count <= 0;
            layer_e1_count <= 0;
            layer_e2_count <= 0;
            layer_m1_count <= 0;
            layer_m2_count <= 0;
            layer_m3_count <= 0;
            layer_m4_count <= 0;
            layer_d1_count <= 0;
            layer_h_count <= 0;
            layer_h_stall <= 0;

            layer_e1_spike_count <= 0;
            layer_e2_spike_count <= 0;
            layer_m1_spike_count <= 0;
            layer_m2_spike_count <= 0;
            layer_m3_spike_count <= 0;
            layer_m4_spike_count <= 0;
            layer_d1_spike_count <= 0;
        end
    end


    // ------------------------------ TOP LEVEL FSM
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= TOP_IDLE;
        end else begin
            state <= next_state;
        end
    end

    assign busy = state != WAIT_INIT && state != TOP_IDLE;
    always_comb begin : top_fsm_comb
        next_state = state;

        case (state)
            TOP_IDLE: begin
                if (en) begin
                    next_state = LOAD_INSTR;
                end
            end
            LOAD_INSTR: begin
                next_state = SETUP_CONFIGURATIONS;
            end
            SETUP_CONFIGURATIONS: begin
                if (layer_count == LAYER_E1) begin
                    next_state = WAIT_INIT;
                end else begin
                    next_state = RUN_LAYER;
                end
            end
            WAIT_INIT: begin
                if (run) begin
                    next_state = RUN_LAYER;
                end
            end
            RUN_LAYER: begin
                next_state = WAIT_LAYER;
            end
            WAIT_LAYER: begin
                // Logic to determine when to transition back to IDLE or LOAD_INSTR for the next layer
                if (layer_idle) begin
                    if (layer_count == LAYER_HEAD) begin
                        next_state = TOP_IDLE;
                    end else begin
                        next_state = LOAD_INSTR;
                    end
                end
            end
            default: begin
                next_state = TOP_IDLE;
            end
        endcase
    end : top_fsm_comb

    always_ff @(posedge clk) begin : top_fsm_ff
        if (!rst_n) begin
            layer_count <= NULL_LAYER;

            instr_addr <= 0;

            run_layer <= 1'b0;
            timestep_count <= 0;

        end else begin
            run_layer <= 1'b0;
            load_next_mst <= 0;
            reset_mst <= 0;

            case (state)
                TOP_IDLE: begin
                    layer_count <= NULL_LAYER;

                    instr_addr  <= 0;
                    reset_mst   <= 1;
                end
                LOAD_INSTR: begin
                    if (instr_addr >= C_NUM_LAYERS * 2) begin
                        instr_addr <= 0;
                    end else begin
                        instr_addr <= instr_addr + 2;
                    end
                    instr1_reg <= instr_word1_t'(instr1);
                    instr2_reg <= instr_word2_t'(instr2);
                    layer_count <= layer_count.next();
                    //  load M0 and shift and threshold as well
                    // m0, shift, and threshold are loaded per layer, not per input fm so it is better to do it here
                    load_next_mst <= 1;

                end
                SETUP_CONFIGURATIONS: begin
                    // Setup weight
                end
                WAIT_INIT: begin
                    if (run) begin
                        if (timestep_count >= C_NUM_TIMESTEPS) begin
                            timestep_count <= 1; // reset to 1 since we expect to be at 1 when checking for reset mem
                        end else begin
                            timestep_count <= timestep_count + 1;
                        end
                    end
                end
                RUN_LAYER: begin
                    run_layer <= 1'b1;
                end
                WAIT_LAYER: begin
                end
                default: begin
                end
            endcase
        end
    end : top_fsm_ff
    // ------------------------------ TOP LEVEL FSM



    // ------------------------------ LAYER FSM


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_layer <= LAYER_IDLE;
        end else begin
            state_layer <= next_state_layer;
        end
    end

    always_comb begin : layer_fsm_comb
        next_state_layer = state_layer;
        layer_idle = 1'b0;

        case (state_layer)
            LAYER_IDLE: begin
                layer_idle = 1'b1;
                if (run_layer) begin
                    layer_idle = 1'b0;
                    next_state_layer = SET_LAYER;
                end
            end
            SET_LAYER: begin
                next_state_layer = LOAD_WEIGHT;

                if (layer_count == LAYER_HEAD) begin
                    next_state_layer = COMPUTE_FH;  // head layer doesn't have weights to load, goes straight to compute FH
                end
            end
            LOAD_WEIGHT: begin
                if (weight_count >= instr1_reg.out_c) begin
                    next_state_layer = COMPUTE_S1;
                end
            end
            COMPUTE_S1: begin  // fm to sum
                next_state_layer = WAIT_S1;
            end
            WAIT_S1: begin
                if (layer_count == LAYER_E1) next_state_layer = COMPUTE_S2;  // layer 1 specifically goes to idle state since it continuously outputs sum

                if (all_ready) begin
                    if (fm_rd_sel < instr1_reg.in_c - 1) begin
                        next_state_layer = INCR_FM;
                    end else begin  // done reading all fms
                        next_state_layer = COMPUTE_S2;
                    end
                end
            end
            INCR_FM: begin
                next_state_layer = LOAD_WEIGHT;
            end
            COMPUTE_S2: begin  // sum to fm
                next_state_layer = WAIT_S2;
            end
            WAIT_S2: begin
                if (all_ready) begin
                    next_state_layer = LAYER_IDLE;
                end
                if (layer_count == LAYER_E1 && all_ready) begin
                    next_state_layer = LAYER_IDLE;
                end
            end
            COMPUTE_FH: begin
                next_state_layer = WAIT_FH;
            end
            WAIT_FH: begin
                if (fh_done_proc_out) begin
                    if (timestep_count >= C_NUM_TIMESTEPS) begin
                        next_state_layer = RESET_MEM;  // reset membranes after designated number of timesteps
                    end else begin
                        next_state_layer = LAYER_IDLE;
                    end
                end
            end
            RESET_MEM: begin
                next_state_layer = LAYER_IDLE;
            end
            default: begin
                next_state_layer = LAYER_IDLE;
            end
        endcase
    end : layer_fsm_comb

    always_ff @(posedge clk) begin : layer_fsm_ff
        if (!rst_n) begin
            // Reset logic for layer FSM
            fm_state_sel <= FM_IDLE;
            sum_state_sel <= SUM_IDLE;
            membrane_state_sel <= MEM_IDLE;
            fh_state_sel <= FH_IDLE;

            kernel_stride <= 2'b01;
            fm_reader_source_sel <= 1'b0;
            fm_reader_start <= 1'b0;
            fm_rd_sel <= 0;
            kernel_en <= '{default: 1'b0};
            weight_sample <= 0;
            read_reset <= 1'b0;
        end else begin
            fm_reader_start <= 1'b0;
            weight_count <= 0;
            kernel_select <= 0;
            weight_sample <= 0;
            read_reset <= 1'b0;

            case (state_layer)
                LAYER_IDLE: begin
                    // Logic for IDLE state
                    fm_state_sel <= FM_IDLE;
                    sum_state_sel <= SUM_IDLE;
                    membrane_state_sel <= MEM_IDLE;
                    fh_state_sel <= FH_IDLE;

                    kernel_stride <= 2'b01;
                    fm_reader_source_sel <= 1'b0;
                    fm_reader_start <= 1'b0;
                    fm_rd_sel <= 0;

                    kernel_en <= '{default: 1'b0};
                    weight_addr <= instr2_reg.weight_addr;
                end

                SET_LAYER: begin
                    kernel_stride <= instr1_reg.stride;
                    fm_reader_source_sel <= instr1_reg.fm_source;
                    for (int i = 0; i < C_PCHANNELS; i++) begin
                        if (i < instr1_reg.out_c) begin
                            kernel_en[i] <= 1'b1;
                        end else begin
                            kernel_en[i] <= 1'b0;
                        end
                    end
                end
                LOAD_WEIGHT: begin
                    weight_sample <= 1;

                    if (weight_count <= instr1_reg.out_c - 1) begin
                        weight_addr  <= weight_addr + 1;
                        weight_count <= weight_count + 1;
                    end

                    if (weight_sample) begin
                        k_weight[kernel_select] <= weight_data;
                        kernel_select <= kernel_select + 1;
                    end

                end
                COMPUTE_S1: begin
                    // Logic to compute from fm to sum
                    fm_reader_start <= 1'b1;
                    membrane_state_sel <= MEM_IDLE;
                    case (layer_count)
                        LAYER_E1: begin  // e1
                            sum_state_sel <= SUM_TEMP_BUFF;
                        end
                        default: begin  // m1, m2, m3, m4, d1
                            sum_state_sel <= SUM_ACCUM;
                            fm_state_sel  <= FM_READ;
                        end
                    endcase
                end
                WAIT_S1: begin
                    // Wait for fm to sum computation to finish
                end
                INCR_FM: begin
                    fm_rd_sel <= fm_rd_sel + 1;
                end
                COMPUTE_S2: begin

                    fm_state_sel <= (layer_count == LAYER_D1) ? FM_IDLE : FM_WRITE;
                    membrane_state_sel <= (instr1_reg.snn) ? MEM_LIF : MEM_THRESHOLD;

                    if (layer_count == LAYER_E1) begin
                        sum_state_sel <= sum_state_sel;
                    end else if (layer_count == LAYER_E2) begin
                        sum_state_sel <= SUM_READOUT_80;
                    end else begin
                        sum_state_sel <= SUM_READOUT_40;
                    end

                    fh_state_sel <= (layer_count == LAYER_D1) ? FH_STORE : FH_IDLE;

                end
                WAIT_S2: begin
                    // Wait for sum to fm computation to finish
                end

                COMPUTE_FH: begin
                    fm_reader_start <= 1'b1;
                    fh_state_sel <= FH_RUN;
                    read_reset <= 1'b1; 
                end
                WAIT_FH: begin
                    // Wait for flow head computation to finish
                    fh_state_sel <= FH_IDLE;
                    read_reset <= 1'b1; 
                end
                RESET_MEM: begin
                    membrane_state_sel <= MEM_RESET;
                end
                default: begin
                end
            endcase
        end
    end : layer_fsm_ff
    // ------------------------------ LAYER FSM


    genvar i_kernel;


    // Feature map signals 
    // stores feature maps
    fm_top fm_top_inst (
        .clk         (clk),
        .rst_n       (rst_n),
        .state_sel   (fm_state_sel),
        .dim         (instr1_reg.dim),
        .fm_top_ready(fm_top_ready),

        // membrane_top signals
        .x       (fm_x),
        .y       (fm_y),
        .xy_valid(fm_xy_valid),

        // fm_reader signals
        .fm_rd_sel    (fm_rd_sel),      // select 0 - 15, from control fsm
        .fm_addr      (fm_addr),
        .fm_addr_valid(fm_addr_valid),
        .fm_dout      (fm_dout),
        .fm_dout_valid(fm_dout_valid),

        .done_proc_in(membrane_top_done_proc_out)
    );


    // reads feature maps from either image buffer or fm_top
    fm_reader u_fm_reader (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (fm_reader_start),       // for control fsm, possibly remove
        .fm_source_sel  (fm_reader_source_sel),  // for control fsm
        .dim            (instr1_reg.dim),
        .fm_reader_ready(fm_reader_ready),
        .fm_rd_sel      (fm_rd_sel),             // select 0 - 15, from control fsm

        // image buffer
        .s0_addr      (img_buff_addr),
        .s0_addr_valid(img_buff_addr_valid),
        .s0_dout      (img_buff_data),
        .s0_dout_valid(img_buff_data_valid),

        // fm top
        .s1_addr      (fm_addr),
        .s1_addr_valid(fm_addr_valid),
        .s1_dout      (fm_dout),
        .s1_dout_valid(fm_dout_valid),

        .x       (fm_evt_x),
        .y       (fm_evt_y),
        .xy_valid(fm_evt_valid),

        .kernel_ready(layer_count == LAYER_HEAD ? fh_ready : kernel_ready[0]),

        .done_proc_out(fm_reader_done_proc_out),

        // debug register
        .enable_count(enable_count && layer_count == LAYER_HEAD), // only count for fm reader when processing head layer, avoid duplicate counts
        .enable_count_pulse(enable_count_pulse),
        .event_count(event_count)
    );


    generate
        for (i_kernel = 0; i_kernel < C_PCHANNELS; i_kernel = i_kernel + 1) begin : kernel_loop
            kernel kernel_inst (
                .clk      (clk),
                .rst_n    (rst_n),
                .ready    (kernel_ready[i_kernel]),
                .kernel_en(kernel_en[i_kernel]),
                .sum_ready(layer_count == LAYER_E1 ? sum_ready : 1'b1), // only needed for layer e1

                .dim      (instr1_reg.dim),
                .weight_in(k_weight[i_kernel]),
                .stride   (kernel_stride),

                // input spikes
                .x       (fm_evt_x),
                .y       (fm_evt_y),
                .xy_valid(fm_evt_valid),

                // output kv values
                .x_out       (kernel_x[i_kernel]),
                .y_out       (kernel_y[i_kernel]),
                .kv          (kernel_kv[i_kernel]),
                .xy_out_valid(kernel_valid[i_kernel]),

                .y_line(kernel_y_line[i_kernel]),
                .x_line(kernel_x_line[i_kernel]),

                .done_proc_in (fm_reader_done_proc_out),
                .done_proc_out(kernel_done_proc_out[i_kernel])
            );
        end
    endgenerate


    sum sum_inst (
        .clk  (clk),
        .rst_n(rst_n),

        .state_sel   (sum_state_sel),
        .dim         (layer_count == LAYER_E2 ? 8'd80 : 8'd40),
        .readout_done(readout_done),
        .sum_ready   (sum_ready),

        .x       (kernel_x[0]),
        .y       (kernel_y[0]),
        .kv      (kernel_kv),
        .xy_valid(kernel_valid),
        .y_line  (kernel_y_line[0]),
        .x_line  (kernel_x_line[0]),

        .sum_x    (sum_x),
        .sum_y    (sum_y),
        .sum_out  (sum_out),
        .sum_valid(sum_valid),

        .done_proc_in (kernel_done_proc_out[0]),
        .done_proc_out(sum_done_proc_out)

    );

    q_scale q_scale_inst (
        .clk  (clk),
        .rst_n(rst_n),

        .sum_x    (sum_x),
        .sum_y    (sum_y),
        .sum_in   (sum_out),
        .sum_valid(sum_valid),

        .m0   (k_m0),
        .shift(k_shift),

        .q_x        (q_x),
        .q_y        (q_y),
        .q_out      (q_out),
        .q_out_valid(q_out_valid),

        .done_proc_in (sum_done_proc_out),
        .done_proc_out(q_scale_done_proc_out)

    );

    membrane_top membrane_top_inst (
        .clk               (clk),
        .rst_n             (rst_n),
        .state_sel         (membrane_state_sel),
        .membrane_top_ready(membrane_top_ready),

        .mem_offset(instr2_reg.mem_addr),
        .threshold (k_threshold),

        .x       (q_x),
        .y       (q_y),
        .I       (q_out),
        .xy_valid(q_out_valid),

        .x_spike    (mem_x_spike),
        .y_spike    (mem_y_spike),
        .valid_spike(mem_valid_spike),
        .valid_out  (mem_valid_out),

        .done_proc_in (q_scale_done_proc_out),
        .done_proc_out(membrane_top_done_proc_out)
    );


    always_comb begin
        fm_x = mem_x_spike;
        fm_y = mem_y_spike;
        fm_xy_valid = mem_valid_spike;

        fh_xy_valid = mem_valid_spike;
        fh_in_valid = mem_valid_out;

        filter_x = fm_evt_x;
        filter_y = fm_evt_y;
        filter_xy_valid = fm_evt_valid;
    end


    flow_head flow_head_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .state_sel    (fh_state_sel),
        .done_proc_in (fm_reader_done_proc_out),
        .done_proc_out(fh_done_proc_out),

        .valid_spike(fh_xy_valid),
        .in_valid   (fh_in_valid),

        .filter_x       (filter_x),
        .filter_y       (filter_y),
        .filter_xy_valid(filter_xy_valid),
        .fh_ready       (fh_ready),

        .out_x    (fh_x),
        .out_y    (fh_y),
        .out_u    (fh_u),
        .out_v    (fh_v),
        .out_valid(fh_valid),

        .axis_m_ready(axis_m_ready)
    );





endmodule
