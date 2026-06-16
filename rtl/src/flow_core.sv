// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps 
`default_nettype none

import design_pkg::*;
// Skeleton top for SNN flow; instantiates flow_control_hub, timer, and placeholders for compute blocks.
module flow_core (
    input wire clk,
    input wire rst_n,

    // Control plane
    input  wire  en,    // Enable signal for image buffer and timer
    output logic busy,
    output logic done,

    output logic buf_swap,     // Buffer swap signal for image buffer
    input  wire  buf_swap_ack,

    output logic read_reset,
    output logic [11:0] addr_readout,
    output logic        addr_readout_valid,
    input  wire  [31:0] data_readout,
    input  wire         data_readout_valid,

    output logic [       8:0] fh_x,
    output logic [       8:0] fh_y,
    output logic [MEMB_I-1:0] fh_u,
    output logic [MEMB_I-1:0] fh_v,
    output logic              fh_valid,
    output logic              fh_done_proc,
    output logic [3:0] timestep_count,

    input wire axis_m_ready,
    input wire [31:0]timer_count,

    // debug registers
    input wire enable_count,
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
    // Timing pulses for downstream (e.g., image_buffer swap on 5 ms pulse)
    logic pulse_5ms;

    logic snn_run;
    logic snn_busy;
    logic snn_en;

    logic pulse_5ms_sticky;
    logic pulse_5ms_clear;

    assign busy = snn_busy;

    typedef enum {
        IDLE,
        WAIT_TIMER,
        SNN_WAIT_READY,
        BUFFER_SWAP_WAIT_READY,
        SNN_RUN,
        SNN_RESET
    } control_state_t;
    control_state_t state, next_state;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (en) begin
                    next_state = WAIT_TIMER;
                end
            end
            WAIT_TIMER: begin
                if (pulse_5ms_sticky) begin
                    next_state = SNN_WAIT_READY;
                end

                if (~en) next_state = IDLE;
            end
            SNN_WAIT_READY: begin
                if (!snn_busy) begin
                    next_state = BUFFER_SWAP_WAIT_READY;
                end
            end
            BUFFER_SWAP_WAIT_READY: begin
                if (buf_swap_ack) begin
                    next_state = SNN_RUN;
                end
            end
            SNN_RUN: begin
                next_state = WAIT_TIMER;
            end
            default: begin
                next_state = IDLE;
            end

        endcase

    end


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            buf_swap <= 1'b0;
            snn_run <= 1'b0;
            done <= 1'b0;
            snn_en <= 1'b0;

        end else begin
            pulse_5ms_clear <= 1'b0;  // Clear the sticky pulse after acknowledging
            done <= 1'b0;
            snn_run <= 1'b0;  // Stop the SNN execution

            case (state)
                IDLE: begin
                    snn_en <= 1'b0;
                    if (en) snn_en <= 1'b1;  // Enable the SNN when starting
                end
                WAIT_TIMER: begin
                end
                SNN_WAIT_READY: begin
                    if (~snn_busy && pulse_5ms_sticky) begin
                        pulse_5ms_clear <= 1'b1;  // Clear the sticky pulse after acknowledging
                        buf_swap <= ~buf_swap;  // Clear the sticky pulse after acknowledging
                    end
                end
                BUFFER_SWAP_WAIT_READY: begin
                end
                SNN_RUN: begin
                    snn_run <= 1'b1;  // Start the SNN execution
                end
                default: begin
                end

            endcase
        end
    end


    // Generate sticky pulses for buffer swap and execution control
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pulse_5ms_sticky  <= 1'b0;
        end else begin
            if (pulse_5ms) pulse_5ms_sticky <= 1'b1;

            if (pulse_5ms_clear) pulse_5ms_sticky <= 1'b0;
        end
    end

    timer_inf u_timer_inf (
        .clk       (clk),
        .arstn     (rst_n),
        .en        (snn_en),
        .pulse_5ms (pulse_5ms),
        .timer_count(timer_count)
    );


    flow_snn u_flow_snn (
        .clk  (clk),
        .rst_n(rst_n),

        .en   (snn_en),
        .run  (snn_run),
        .busy (snn_busy),

        .read_reset        (read_reset),
        .img_buff_addr      (addr_readout),
        .img_buff_addr_valid(addr_readout_valid),
        .img_buff_data      (data_readout),
        .img_buff_data_valid(data_readout_valid),

        .fh_x   (fh_x),
        .fh_y   (fh_y),
        .fh_u   (fh_u),
        .fh_v   (fh_v),
        .fh_valid(fh_valid),
        .fh_done_proc_out(fh_done_proc),
        .timestep_count(timestep_count),

        .axis_m_ready(axis_m_ready),

                // Registers
        .enable_count   (enable_count),
        .event_count   (event_count),     // input unique spike count over the last x ms
        .busy_count    (busy_count),      // clock cycles spent busy over the last x ms
        .idle_count    (idle_count),      // clock cycles spent idle over the last x ms
        .inference_count(inference_count), // number of complete inferences completed
        .layer_e1_count(layer_e1_count),  // clock cycles spent in layer 1 over the last x ms
        .layer_e2_count(layer_e2_count),  // clock cycles spent in layer 2 over the last x ms
        .layer_m1_count(layer_m1_count),  // clock cycles spent in layer 3 over the last x ms
        .layer_m2_count(layer_m2_count),  // clock cycles spent in layer 4 over the last x ms
        .layer_m3_count(layer_m3_count),  // clock cycles spent in layer 5 over the last x ms
        .layer_m4_count(layer_m4_count),  // clock cycles spent in layer 6 over the last x ms
        .layer_d1_count(layer_d1_count),  // clock cycles spent in layer 7 over the last x ms
        .layer_h_count (layer_h_count),    // clock cycles spent in layer 8 over the last x ms
        .layer_h_stall(layer_h_stall), // clock cycles spent stalled in layer 8 over the last x ms

        .layer_e1_spike_count(layer_e1_spike_count),
        .layer_e2_spike_count(layer_e2_spike_count),
        .layer_m1_spike_count(layer_m1_spike_count),
        .layer_m2_spike_count(layer_m2_spike_count),
        .layer_m3_spike_count(layer_m3_spike_count),
        .layer_m4_spike_count(layer_m4_spike_count),
        .layer_d1_spike_count(layer_d1_spike_count)
    );




endmodule
