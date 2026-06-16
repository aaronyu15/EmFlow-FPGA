`timescale 1ps/1ps
`default_nettype none

import design_pkg::*;

module ram_mst (
    input wire clk,
    input wire rst_n,

    input wire load_next_mst,
    input wire reset_mst,

    input wire [5:0] num_out_ch,

    output logic [M0_WIDTH-1:0] m0 [C_PCHANNELS],
    output logic [SHIFT_WIDTH-1:0] shift [C_PCHANNELS],
    output logic [THRESHOLD_WIDTH-1:0] threshold
);
    
    // RAM storage
    typedef enum {
        MS_IDLE,
        MS_LOAD
    } ms_state_t;

    typedef enum {
        T_IDLE,
        T_LOAD
    } t_state_t;
    
    // memory for m0. applies per output feature map (e.g. kernel 15 for output map 15 uses a constant
    // m0 value across all input channels
    (* ram_style = "distributed" *)
    logic [M0_WIDTH-1:0] m_mem [M0_SIZE];

    // memory for shift values. Same note as m0
    (* ram_style = "distributed" *)
    logic [SHIFT_WIDTH-1:0] s_mem [SHIFT_SIZE];

    // memory for threshold values. One value per layer
    (* ram_style = "distributed" *)
    logic [THRESHOLD_WIDTH-1:0] t_mem [THRESHOLD_SIZE];

`ifdef SYNTHESIS
    initial begin
        $readmemh("m0.mem", m_mem);
        $readmemh("shift.mem", s_mem);
        $readmemh("threshold.mem", t_mem);
    end
`else
    initial begin
        $readmemh(M0_MEM_FILE, m_mem);
        $readmemh(SHIFT_MEM_FILE, s_mem);
        $readmemh(THRESHOLD_MEM_FILE, t_mem);
    end
`endif

    ms_state_t ms_state, ms_state_next;
    t_state_t t_state, t_state_next;

    logic [7:0] ms_addr;
    logic [7:0] ms_count;

    logic [7:0] t_addr;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ms_state <= MS_IDLE;
            t_state <= T_IDLE;
        end else begin
            ms_state <= ms_state_next;
            t_state <= t_state_next;
        end
    end

    always_comb begin
        ms_state_next = ms_state;
        t_state_next = t_state;

        case(ms_state)
            MS_IDLE: begin
                if (load_next_mst) begin
                    ms_state_next = MS_LOAD;
                end
            end
            MS_LOAD: begin
                if (ms_count == num_out_ch - 1) begin
                    ms_state_next = MS_IDLE;
                end
            end
        endcase

        case(t_state)
            T_IDLE: begin
                if (load_next_mst) begin
                    t_state_next = T_LOAD;
                end
            end
            T_LOAD: begin
                t_state_next = T_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // reset logic if needed
            ms_addr <= 0;
            t_addr <= 0;
            ms_count <= 0;
        end else begin
            case (ms_state)
                MS_IDLE: begin
                end
                MS_LOAD: begin
                    ms_addr <= ms_addr + 1;
                    ms_count <= ms_count + 1;

                    if (ms_count == num_out_ch - 1) begin
                        ms_count <= 0; // reset count for next layer
                    end

                    m0[ms_count] <= m_mem[ms_addr];
                    shift[ms_count] <= s_mem[ms_addr];
                end
            endcase

            case (t_state)
                T_LOAD: begin
                    t_addr <= t_addr + 1;
                    threshold <= t_mem[t_addr];
                end
            endcase

            if (reset_mst) begin
                ms_addr <= 0;
                t_addr <= 0;
            end
        end
    end



    //========================================================================
    //NETWORK STRUCTURE OVERVIEW
    //========================================================================
    //  Layer           Weight Shape       Stride  Pad Groups LIF Type
    //  ----------------------------------------------------------------------
    //  e1              8x1x3x3                 2    1      1 QuantizedLIF (spike_no_membrane)
    //  e2              8x8x3x3                 2    1      1 QuantizedLIF (spike_no_membrane)
    //  m1              16x8x3x3                2    1      1 QuantizedLIF
    //  m2              16x16x3x3               1    1      1 QuantizedLIF
    //  m3              16x16x3x3               1    1      1 QuantizedLIF
    //  m4              16x16x3x3               1    1      1 QuantizedLIF
    //  d1              8x16x3x3                1    1      1 QuantizedLIF (spike_no_membrane)
    //  flow_head       2x8x3x3                 1    1      1 — (no LIF)
    //
    // total number of weights: 1176 addresses * 9 * 8 bit
    // total number of M0 values: 98 addresses * 12 bit
    // total number of shift values: 98 addresses * 5 bit
endmodule