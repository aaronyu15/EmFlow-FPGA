// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

package design_pkg;

    // ============================================================================
    // Hardware Configuration Parameters
    // ============================================================================
    localparam int unsigned C_NUM_FM = 16;
    localparam int unsigned C_PCHANNELS = 16;

    // Image/Feature map dimensions
    localparam int unsigned C_MAX_H = 320;
    localparam int unsigned C_MAX_W = 320;
    localparam int unsigned C_NUM_LAYERS = 7;
    localparam int unsigned C_NUM_TIMESTEPS = 5;
    localparam int unsigned C_LAYER_E1 = 1;
    localparam int unsigned C_LAYER_E2 = 2;
    localparam int unsigned C_LAYER_M1 = 3;
    localparam int unsigned C_LAYER_M2 = 4;
    localparam int unsigned C_LAYER_M3 = 5;
    localparam int unsigned C_LAYER_M4 = 6;
    localparam int unsigned C_LAYER_D1 = 7;
    localparam int unsigned C_LAYER_HEAD = 8;
    localparam int unsigned C_W = 40;
    localparam int unsigned C_H = 40;
    localparam int unsigned C_NUM_OUT_CHANNELS = C_PCHANNELS/2 + C_PCHANNELS/2 + C_PCHANNELS *4 + C_PCHANNELS/2;  // number of output channels at each layer, excludes flow head

    // Module specific params
    parameter int THRESHOLD_WIDTH = 8;  // bits per threshold
    parameter int M0_WIDTH = 12;  // bits per threshold
    parameter int SHIFT_WIDTH = 8;  // bits per threshold

    parameter int THRESHOLD_SIZE = 7;  // one per layer
    parameter int M0_SIZE = C_NUM_OUT_CHANNELS;  // per layer per output channel
    parameter int SHIFT_SIZE = C_NUM_OUT_CHANNELS;  // per layer per output channel
    /* these do not account for flow head yet ^^^^ */


    // ram image
    parameter IMG_AWIDTH = 12;  // Address Width, 12 = 1 uram
    parameter IMG_DWIDTH = 32;  // Data Width

    // ram instruction
    parameter int unsigned INSTR_AWIDTH = 6;
    parameter int unsigned INSTR_DWIDTH = 36;
    parameter string INSTR_MEM_FILE = "../rtl/src/mem/files/instruct.mem";  // 512 x 36 bram

    // ram weight
    parameter int unsigned WEIGHT_AWIDTH = 11;  // 2048 entries
    parameter int unsigned WEIGHT_DWIDTH = 72;
    parameter int unsigned WEIGHT_WIDTH = 8;
    parameter string WEIGHT_MEM_FILE = "../rtl/src/mem/files/weights.mem";  // 512 x 36 bram
    parameter string M0_MEM_FILE = "../rtl/src/mem/files/m0.mem";  // 512 x 36 bram
    parameter string SHIFT_MEM_FILE = "../rtl/src/mem/files/shift.mem";  // 512 x 36 bram
    parameter string THRESHOLD_MEM_FILE = "../rtl/src/mem/files/threshold.mem";  // 512 x 36 bram

    parameter string FH_WEIGHT_MEM_FILE = "../rtl/src/mem/files/flow_head_weights.mem";  // 512 x 36 bram
    parameter string FH_M0_MEM_FILE = "../rtl/src/mem/files/flow_head_m0.mem";  // 512 x 36 bram
    parameter string FH_SHIFT_MEM_FILE = "../rtl/src/mem/files/flow_head_shift.mem";  // 512 x 36 bram

    // ram flow head
    parameter int unsigned FH_AWIDTH = 11;  // 2048 entries
    parameter int unsigned FH_DWIDTH = C_PCHANNELS/2; // 8 feature maps in parallel
    parameter int unsigned FH_SIZE = FH_DWIDTH * C_H * C_W; // 8 feature maps in parallel

    // flow head fifo
    parameter int unsigned FH_FIFO_AWIDTH = 6;  // 2048 entries
    parameter int unsigned FH_FIFO_DWIDTH = 18; // x y
    parameter int unsigned FH_FIFO_DEPTH = 2 ** FH_FIFO_AWIDTH; // 8 feature maps in parallel

    // fm top
    parameter int FM_AWIDTH = 10;  // 1024 entries per FM
    parameter int FM_DWIDTH = 32;  // 1024 entries per FM

    // fm reader
    parameter int FMRD_AWIDTH = 12;  // 1024 entries per FM
    parameter int FMRD_DWIDTH = 32;  // 1024 entries per FM

    // Kernel
    parameter int K_WIDTH = 8;  // bits per kernel weight

    // Sum
    parameter int SUM_AWIDTH = 13;  // 13 = 8192 entries
    parameter int SUM_WIDTH = 13;  // bits per sum
    parameter int SUM_DWIDTH = C_PCHANNELS * SUM_WIDTH;  // 16 ch * 8 bit = 128 bit
    parameter int SUM_SIZE = 4 * C_H * C_W * SUM_DWIDTH;

    // Membrane
    parameter int MEMB_AWIDTH = 14;  // 13 = 8192 entries
    parameter int MEMB_WIDTH = 9;  // bits per membrane potential
    parameter int MEMB_DWIDTH = C_PCHANNELS * MEMB_WIDTH;  // 16 ch * 8 bit = 128 bit
    parameter int MEMB_SIZE = 4 * C_H * C_W * MEMB_DWIDTH;  // Total bits in membrane memory
    parameter int MEMB_I = 9;



    // ============================================================================
    // Event Data Structure
    // ============================================================================
    typedef struct packed {
        logic [3:0]  evt_type;
        logic [5:0]  timestamp;
        logic [10:0] x;
        logic [10:0] y;
        logic [31:0] x_valid;
    } evt_data_t;

    // ============================================================================
    // Instruction Data Structures (matches microcode format)
    // ============================================================================
    // Instruction Word 1: Layer configuration
    typedef struct packed {
        logic [10:0] reserved;
        logic [8:0] dim;              // Input dimension (height/width)
        logic [5:0]  in_c;      // Input channels (0-15)
        logic [5:0]  out_c;     // Output channels (0-15)
        logic [1:0]  stride;    // Stride for convolution
        logic        fm_source;  // 0 = input buffer, 1 = fm rams
        logic        snn;       // 0 = MEM_THRSHOLD, 1 = MEM_LIF
    } instr_word1_t;

    // Instruction Word 2: Spatial and weight addressing
    typedef struct packed {
        logic [8:0] num_weight_addr;  // Number of weight memory addresses
        logic [11:0] weight_addr;      // Starting weight address
        logic [13:0] mem_addr;      // Starting membrane address
    } instr_word2_t;


    // Combined instruction structure
    typedef struct packed {
        instr_word1_t w1;
        instr_word2_t w2;
    } layer_instr_t;

    typedef enum {
        TOP_IDLE,
        LOAD_INSTR,
        SETUP_CONFIGURATIONS,
        WAIT_INIT,
        RUN_LAYER,
        WAIT_LAYER
    } state_top_t;

    typedef enum {
        LAYER_IDLE,
        LOAD_WEIGHT,
        SET_LAYER,
        COMPUTE_S1,   // fm to sum
        WAIT_S1,
        INCR_FM,
        COMPUTE_S2,   // sum to fm
        WAIT_S2,
        COMPUTE_FH,
        WAIT_FH,
        RESET_MEM
    } state_layer_t;

    typedef enum {
        FM_IDLE,
        FM_RESET,
        FM_WRITE,
        FM_READ
    } state_fm_t;

    typedef enum {
        SUM_IDLE,
        SUM_RESET,
        SUM_ACCUM,
        SUM_READOUT_40,
        SUM_READOUT_80,
        SUM_TEMP_BUFF
    } state_sum_t;
    typedef enum {
        MEM_IDLE,
        MEM_THRESHOLD,
        MEM_PRE_RESET,
        MEM_RESET,
        MEM_LIF
    } state_membrane_t;

    typedef enum {
        FH_IDLE,
        FH_STORE,
        FH_RUN,
        FH_RESET_MEM
    } state_fh_t;

    typedef enum {
        NULL_LAYER = 0,
        LAYER_E1   = 1,
        LAYER_E2   = 2,
        LAYER_M1   = 3,
        LAYER_M2   = 4,
        LAYER_M3   = 5,
        LAYER_M4   = 6,
        LAYER_D1   = 7,
        LAYER_HEAD = 8
    } layer_name_t;

    // Functions
    function automatic log2(input int unsigned value);
        int unsigned i;
        log2 = 0;
        for (i = value - 1; i > 0; i = i >> 1) begin
            log2 = log2 + 1;
        end
        return log2;
    endfunction


    function automatic void get_layer_info(input layer_name_t layer, output int num_in_ch, output int num_out_ch, output string layer_name, output int out_dim); 
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
        case(layer)
            LAYER_E1: begin
                num_in_ch = 1;
                num_out_ch = 8;
                layer_name = "e1";
                out_dim = 160;
            end
            LAYER_E2: begin
                num_in_ch = 8;
                num_out_ch = 8;
                layer_name = "e2";
                out_dim = 80;

            end
            LAYER_M1: begin
                num_in_ch = 8;
                num_out_ch = 16;
                layer_name = "m1";
                out_dim = 40;
            end
            LAYER_M2: begin
                num_in_ch = 16;
                num_out_ch = 16;
                layer_name = "m2";
                out_dim = 40;
            end
            LAYER_M3: begin
                num_in_ch = 16;
                num_out_ch = 16;
                layer_name = "m3";
                out_dim = 40;
            end
            LAYER_M4: begin
                num_in_ch = 16;
                num_out_ch = 16;
                layer_name = "m4";
                out_dim = 40;
            end
            LAYER_D1: begin
                num_in_ch = 16;
                num_out_ch = 8;
                layer_name = "d1";
                out_dim = 40;
            end
            LAYER_HEAD: begin
                num_in_ch = 8;
                num_out_ch = 2;
                layer_name = "flow_head";
                out_dim = 320;
            end
            default: begin
                $display($sformatf("ERROR: Invalid layer specified: %0d", layer));
            end
        endcase
    endfunction : get_layer_info

endpackage
