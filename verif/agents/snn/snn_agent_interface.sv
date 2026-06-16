`ifndef SNN_AGENT_INTERFACE
`define SNN_AGENT_INTERFACE

`include "agent_defines.svh"

interface snn_agent_interface (
    input logic aclk,
    aresetn
);

    import design_pkg::*;

    logic pulse_5ms = 0;
    logic en = 0;


    state_top_t state_top;
    state_layer_t state_layer;

    clocking cb @(posedge aclk);
        default input #1step output #0;
        output pulse_5ms, en;
    endclocking

    initial begin
        force `FLOW_TOP.en = en;
        force `FLOW_CORE.pulse_5ms = pulse_5ms;

        force state_top = `FLOW_SNN.state;
        force state_layer = `FLOW_SNN.state_layer;
    end

    // for some reason releasing forces in a function causes it to happen even when not called?
    task automatic disable_forces();
        $display("Time: %t, Disabling forces on SNN agent interface", $time);
        release `FLOW_TOP.en;
    endtask


    // Top level
    task trigger_buf_swap();
        @(cb);
        pulse_5ms <= 1;
        @(cb);
        pulse_5ms <= 0;
    endtask : trigger_buf_swap


    // Image buffer
    function automatic void get_buffer_frame(output logic [71:0] mem[2**IMG_AWIDTH-1:0], input int buffer);
        if (buffer == 0) begin
            for (int i = 0; i < 2 ** IMG_AWIDTH; i++) begin
                case(buffer)
                    0 : mem[i] = `IMG_BUF_0[i];
                    1 : mem[i] = `IMG_BUF_1[i];
                endcase
            end
        end
    endfunction


    function automatic void set_buffer_frame(input logic signed [MEMB_I-1:0] input_int[320][320], input int buffer);

        logic [31:0] temp_word;
        int x_idx;
        int addr;
        int bit_idx;

        for (int y = 0; y < 320; y++) begin
            for (int col = 0; col < 10; col++) begin
                    addr = y*10 + col;
                    for (int x = 0; x < 32; x++) begin
                        bit_idx = col*32 + x;
                        temp_word[x] = input_int[y][bit_idx];
                    end

                    case(buffer)
                        0 : begin
                            `IMG_BUF_0[addr] = temp_word;
                        end
                        1 : begin
                            `IMG_BUF_1[addr] = temp_word;
                        end
                    endcase
            end
        end
    endfunction

    //weight
    function automatic void set_weight(input int kernel, input logic [K_WIDTH*9-1:0] weight);
        case (kernel)
            0:       `K_WEIGHT(0) = weight;
            1:       `K_WEIGHT(1) = weight;
            2:       `K_WEIGHT(2) = weight;
            3:       `K_WEIGHT(3) = weight;
            4:       `K_WEIGHT(4) = weight;
            5:       `K_WEIGHT(5) = weight;
            6:       `K_WEIGHT(6) = weight;
            7:       `K_WEIGHT(7) = weight;
            8:       `K_WEIGHT(8) = weight;
            9:       `K_WEIGHT(9) = weight;
            10:      `K_WEIGHT(10) = weight;
            11:      `K_WEIGHT(11) = weight;
            12:      `K_WEIGHT(12) = weight;
            13:      `K_WEIGHT(13) = weight;
            14:      `K_WEIGHT(14) = weight;
            15:      `K_WEIGHT(15) = weight;
            default: $display("Invalid kernel index");
        endcase
    endfunction

    function automatic void get_weight(input int kernel, output logic [K_WIDTH*9-1:0] weight);
        case(kernel) 
            0:      weight = `K_WEIGHT(0);
            1:       weight = `K_WEIGHT(1);
            2:       weight = `K_WEIGHT(2);
            3:       weight = `K_WEIGHT(3);
            4:       weight = `K_WEIGHT(4);
            5:       weight = `K_WEIGHT(5);
            6:       weight = `K_WEIGHT(6);
            7:       weight = `K_WEIGHT(7);
            8:       weight = `K_WEIGHT(8);
            9:       weight = `K_WEIGHT(9);
            10:      weight = `K_WEIGHT(10);
            11:      weight = `K_WEIGHT(11);
            12:      weight = `K_WEIGHT(12);
            13:      weight = `K_WEIGHT(13);
            14:      weight = `K_WEIGHT(14);
            15:      weight = `K_WEIGHT(15);
            default: $display("Invalid kernel index");
        endcase
    endfunction

    // m0 and shift
    function automatic void set_m0_shift(input int kernel, input logic [M0_WIDTH-1:0] m0, input logic [SHIFT_WIDTH-1:0] shift);
        case (kernel)
            0:       begin `K_M0(0) = m0; `K_SHIFT(0) = shift; end
            1:       begin `K_M0(1) = m0; `K_SHIFT(1) = shift; end
            2:       begin `K_M0(2) = m0; `K_SHIFT(2) = shift; end
            3:       begin `K_M0(3) = m0; `K_SHIFT(3) = shift; end
            4:       begin `K_M0(4) = m0; `K_SHIFT(4) = shift; end
            5:       begin `K_M0(5) = m0; `K_SHIFT(5) = shift; end
            6:       begin `K_M0(6) = m0; `K_SHIFT(6) = shift; end
            7:       begin `K_M0(7) = m0; `K_SHIFT(7) = shift; end
            8:       begin `K_M0(8) = m0; `K_SHIFT(8) = shift; end
            9:       begin `K_M0(9) = m0; `K_SHIFT(9) = shift; end
            10:      begin `K_M0(10) = m0; `K_SHIFT(10) = shift; end
            11:      begin `K_M0(11) = m0; `K_SHIFT(11) = shift; end
            12:      begin `K_M0(12) = m0; `K_SHIFT(12) = shift; end
            13:      begin `K_M0(13) = m0; `K_SHIFT(13) = shift; end
            14:      begin `K_M0(14) = m0; `K_SHIFT(14) = shift; end
            15:      begin `K_M0(15) = m0; `K_SHIFT(15) = shift; end
            default: $display("Invalid kernel index");
        endcase
    endfunction

    function automatic void get_m0_shift(input int kernel, output logic [M0_WIDTH-1:0] m0, output logic [SHIFT_WIDTH-1:0] shift);
        case (kernel)
            0:       begin m0 = `K_M0(0); shift = `K_SHIFT(0); end
            1:       begin m0 = `K_M0(1); shift = `K_SHIFT(1); end
            2:       begin m0 = `K_M0(2); shift = `K_SHIFT(2); end
            3:       begin m0 = `K_M0(3); shift = `K_SHIFT(3); end
            4:       begin m0 = `K_M0(4); shift = `K_SHIFT(4); end
            5:       begin m0 = `K_M0(5); shift = `K_SHIFT(5); end
            6:       begin m0 = `K_M0(6); shift = `K_SHIFT(6); end
            7:       begin m0 = `K_M0(7); shift = `K_SHIFT(7); end
            8:       begin m0 = `K_M0(8); shift = `K_SHIFT(8); end
            9:       begin m0 = `K_M0(9); shift = `K_SHIFT(9); end
            10:      begin m0 = `K_M0(10); shift = `K_SHIFT(10); end
            11:      begin m0 = `K_M0(11); shift = `K_SHIFT(11); end
            12:      begin m0 = `K_M0(12); shift = `K_SHIFT(12); end
            13:      begin m0 = `K_M0(13); shift = `K_SHIFT(13); end
            14:      begin m0 = `K_M0(14); shift = `K_SHIFT(14); end
            15:      begin m0 = `K_M0(15); shift = `K_SHIFT(15); end
            default: $display("Invalid kernel index");
        endcase
    endfunction

    // threshold
    function automatic void set_threshold(input logic signed [THRESHOLD_WIDTH-1:0] threshold);
            `K_THRESHOLD = threshold;

    endfunction

    function automatic void get_threshold(output logic signed [THRESHOLD_WIDTH-1:0] threshold);
            threshold = `K_THRESHOLD;
    endfunction

    // sum
    function automatic void get_sum(output logic signed [SUM_WIDTH-1:0] sum[2**IMG_AWIDTH-1:0][C_PCHANNELS]);
        // mem[0:8191][207:0]
        // SUM_WIDTH per channel, channel 0 at [12:0]
        for (int i = 0; i < 2 ** MEMB_AWIDTH; i++) begin
            for (int j = 0; j < SUM_DWIDTH; j++) begin
                for (int ch = 0; ch < C_PCHANNELS; ch++) begin
                    sum[i][ch] = `SUM_MEM[i][SUM_WIDTH*ch +: SUM_WIDTH];
                end
            end
        end
    endfunction

    // membrane
    function automatic void get_membrane(output logic signed [MEMB_WIDTH-1:0] mem[2**IMG_AWIDTH-1:0][C_PCHANNELS]);
        // mem[0:8191][127:0]
        // MEMB_WIDTH per channel, channel 0 at [7:0]
        for (int i = 0; i < 2 ** MEMB_AWIDTH; i++) begin
            for (int j = 0; j < MEMB_DWIDTH; j++) begin
                for (int ch = 0; ch < C_PCHANNELS; ch++) begin
                    mem[i][ch] = `MEMBRANE_MEM[i][MEMB_WIDTH*ch +: MEMB_WIDTH];
                end
            end
        end
    endfunction


    // fm
    function automatic void get_feature_map(output logic [15:0] fm[160][160]);

    for (int kernel = 0; kernel < C_PCHANNELS; kernel++) begin
        for (int i = 0; i < 160; i++) begin
            for (int j = 0; j < 160; j++) begin
                case(kernel) 
                0 : fm[i][j] = `FM_MEM(0)[i*160+j];
                1 : fm[i][j] = `FM_MEM(1)[i*160+j];
                2 : fm[i][j] = `FM_MEM(2)[i*160+j];
                3 : fm[i][j] = `FM_MEM(3)[i*160+j];
                4 : fm[i][j] = `FM_MEM(4)[i*160+j];
                5 : fm[i][j] = `FM_MEM(5)[i*160+j];
                6 : fm[i][j] = `FM_MEM(6)[i*160+j];
                7 : fm[i][j] = `FM_MEM(7)[i*160+j];
                8 : fm[i][j] = `FM_MEM(8)[i*160+j];
                9 : fm[i][j] = `FM_MEM(9)[i*160+j];
                10 : fm[i][j] = `FM_MEM(10)[i*160+j];
                11 : fm[i][j] = `FM_MEM(11)[i*160+j];
                12 : fm[i][j] = `FM_MEM(12)[i*160+j];
                13 : fm[i][j] = `FM_MEM(13)[i*160+j];
                14 : fm[i][j] = `FM_MEM(14)[i*160+j];
                15 : fm[i][j] = `FM_MEM(15)[i*160+j];
                default: fm[i][j] = `FM_MEM(0)[i*160+j];
                endcase
            end
        end
    end
    endfunction    

    state_fm_t state_fm;
    state_membrane_t state_membrane;
    layer_name_t layer_count;

    initial begin
        force state_fm = `FM_TOP_0.state;
        force state_membrane = `MEMBRANE_TOP_0.state;
        force layer_count = `FLOW_SNN.layer_count;
    end
    // sum checker module signals
    logic SUM_MODULE_SIGNALS = 1'bz;
    logic [8:0] x;
    logic [8:0] y;
    logic signed [K_WIDTH-1:0] kv[C_PCHANNELS];
    logic xy_valid[C_PCHANNELS];

    logic [8:0] sum_x;
    logic [8:0] sum_y;
    logic signed [SUM_WIDTH-1:0] sum_out[C_PCHANNELS];
    logic sum_valid;

    logic [SUM_WIDTH*C_PCHANNELS-1:0] sum_exp[160][160] = '{default: 0};
    logic [159:0] buffer_hit[160] = '{default: 0};
    logic [9:0] current_line = 0;
    logic signed [SUM_WIDTH-1:0] kv_vals[16];
    logic sum_error;

    state_sum_t state_sum;
    initial begin
        // sum module
        force x = `SUM_TOP_0.x;
        force y = `SUM_TOP_0.y;
        force kv = `SUM_TOP_0.kv;
        force xy_valid = `SUM_TOP_0.xy_valid;

        force sum_x = `SUM_TOP_0.sum_x;
        force sum_y = `SUM_TOP_0.sum_y;
        force sum_out = `SUM_TOP_0.sum_out;
        force sum_valid = `SUM_TOP_0.sum_valid;
        force state_sum = `SUM_TOP_0.state;
    end

    always_ff @(posedge aclk) begin : sum_check_block
        sum_error <= 1'b0;

        for (int i = 0; i < C_PCHANNELS; i = i + 1) begin
            // store observed value
            if (xy_valid[i]) begin
                sum_exp[y][x][SUM_WIDTH*i+:SUM_WIDTH] <= $signed(sum_exp[y][x][SUM_WIDTH*i+:SUM_WIDTH]) + $signed(kv[i]);
                buffer_hit[y][x] <= 1'b1;

            end

            if (sum_valid) begin
                // check that output sum matches expected value
                kv_vals[i] = sum_exp[sum_y][sum_x][SUM_WIDTH*i+:SUM_WIDTH];

                if (sum_out[i] != kv_vals[i]) begin
                    $display($sformatf("Time: %t, Error in sum comparison, sum_x: %d sum_y: %d, channel: %d, exp: %d, got: %d", $time, sum_x, sum_y, i, kv_vals[i], sum_out[i]));
                    sum_error <= 1'b1;
                end

                buffer_hit[sum_y][sum_x] <= 1'b0;  // Clear the hit

                current_line <= sum_y;
            end

        end
        // check that if we moved to a new line, the previous line was fully processed
        if (sum_valid && sum_y != current_line) begin
            if (|buffer_hit[current_line]) begin
                $display($sformatf("Time: %t, Error: Line y=%d was not fully processed. Remaining hits: %d", $time, current_line, $countones(buffer_hit[current_line])));
                for (int j = 0; j < 160; j++) begin
                    if (buffer_hit[current_line][j]) begin
                        $display($sformatf("    Unprocessed pixel at x: %d, y: %d, expected value: %d", j, current_line, $signed(sum_exp[current_line][j])));
                    end
                end
                sum_error <= 1'b1;
            end
        end


        if (state_sum == SUM_IDLE) begin
            // reset tracking variables at the start of a new frame
            current_line <= 0;
            for (int i = 0; i < 160; i = i + 1) begin
                buffer_hit[i] <= 0;
                for (int j = 0; j < 160; j = j + 1) begin
                    sum_exp[i][j] <= 0;
                end
            end

        end


    end : sum_check_block


    // Testcase items
    logic check_error = 0;

    logic [SUM_DWIDTH-1:0] act_sum[160][160] = '{default: 0};
    logic [SUM_DWIDTH-1:0] pred_sum[160][160] = '{default: 0};
    logic sum_pred_en = 0;

    function automatic void set_predicted_sum(input logic [SUM_DWIDTH-1:0] pred[160][160]);
        for (int i = 0; i < 160; i++) begin
            for (int j = 0; j < 160; j++) begin
                pred_sum[i][j] = pred[i][j];
            end
        end
        sum_pred_en = 1'b1;
    endfunction

    task automatic check_sum(int dim = 80, int out_ch = 16, layer_name_t layer);
        automatic logic error = 0;

        wait_sum_done();

        if (sum_pred_en) begin


            for (int ch = 0; ch < out_ch; ch++) begin
                for (int i = 0; i < dim; i++) begin
                    for (int j = 0; j < dim; j++) begin
                            int x = j;
                            int y = i;
                            int addr = y * dim + x;

                            act_sum[y][x][SUM_WIDTH*ch +: SUM_WIDTH] = read_sum(ch, addr);
                        end

                    end
                end

            $display($sformatf("Time: %t, Beginning predicted sum check for layer: %0s", $time, layer.name()));

            for (int ch = 0; ch < out_ch; ch++) begin
                for (int j = 0; j < dim; j++) begin
                    for (int i = 0; i < dim; i++) begin
                        if ($signed(act_sum[i][j][SUM_WIDTH*ch +: SUM_WIDTH]) !== $signed(pred_sum[i][j][SUM_WIDTH*ch +: SUM_WIDTH])) begin
                            $display($sformatf("Time: %t, Error in predicted sum comparison at y, x (%0d, %0d) channel: %0d, act: %0d, pred: %0d", $time, i, j, ch, $signed(act_sum[i][j][SUM_WIDTH*ch +: SUM_WIDTH]), $signed(pred_sum[i][j][SUM_WIDTH*ch +: SUM_WIDTH])));

                            error = 1;
                            check_error = 1;
                        end
                    end
                end
            end

            if (!error) begin
                $display($sformatf("Time: %t, Predicted sum check for layer: %0s PASSED", $time, layer.name()));
            end else begin
                $display($sformatf("Time: %t, Predicted sum check for layer: %0s FAILED", $time, layer.name()));
            end

            sum_pred_en = 0;
        end


    endtask : check_sum



    // feature map checker
    logic [15:0] act_fm[160][160] = '{default: 0};
    logic [15:0] pred_fm[160][160] = '{default: 0};
    logic fm_pred_en = 0;

    function automatic void set_predicted_fm(input logic [15:0] pred[160][160]);
        for (int i = 0; i < 160; i++) begin
            for (int j = 0; j < 160; j++) begin
                pred_fm[i][j] = pred[i][j];
            end
        end
        fm_pred_en = 1'b1;
    endfunction

     task automatic check_fm(int dim=160, int out_ch = 16, layer_name_t layer, string loc = "fm_mem");
        automatic logic error = 0;
        int col_count;

        // wait for layer count to change
        @(layer_count);

        if (fm_pred_en) begin
            case(dim)
                160: col_count = 5;
                80: col_count = 3;
                40: col_count = 2;
                default: $display("Time %t Error: Invalid dimension for check_fm: %d", $time, dim);
            endcase

            for (int ch = 0; ch < out_ch; ch++) begin
                for (int i = 0; i < dim; i++) begin

                    if (loc == "fm_mem") begin
                        for (int j = 0; j < col_count; j++) begin
                            for (int k = 0; k < FM_DWIDTH; k++) begin
                                int x = j*FM_DWIDTH + k;
                                int y = i;

                                act_fm[y][x][ch] = read_fm(ch, y*col_count + j, k);

                            end

                        end
                    end else if (loc == "flow_head") begin
                        for (int j = 0; j < dim; j++) begin
                            int x = j;
                            int y = i;

                            act_fm[y][x][ch] = read_fm(ch, y*dim + x, 0, "flow_head");
                        end


                    end
                end
            end

            $display($sformatf("Time: %t, Beginning predicted FM check for layer: %0s", $time, layer.name()));
            for (int ch = 0; ch < out_ch; ch++) begin
                for (int i = 0; i < dim; i++) begin
                    for (int j = 0; j < dim; j++) begin
                        if (act_fm[i][j][ch] !== pred_fm[i][j][ch]) begin
                            $display($sformatf("Time: %t, Error in predicted FM comparison at y, x (%0d, %0d) channel %0d, act: %0d, pred: %0d", $time, i, j, ch, act_fm[i][j][ch], pred_fm[i][j][ch]));
                            error = 1;
                            check_error = 1;
                        end
                    end
                end
            end

            if (!error) begin
                $display($sformatf("Time: %t, Predicted FM check for layer: %0s PASSED", $time, layer.name()));
            end else begin
                $display($sformatf("Time: %t, Predicted FM check for layer: %0s FAILED", $time, layer.name()));
            end

            fm_pred_en = 0;
        end
     endtask : check_fm


    // memb checker
    logic [MEMB_DWIDTH-1:0] act_memb[160][160] = '{default: 0};
    logic [MEMB_DWIDTH-1:0] pred_memb[160][160] = '{default: 0};
    logic memb_pred_en = 0;

    function automatic void set_predicted_memb(input logic [MEMB_DWIDTH-1:0] pred[160][160]);
        for (int i = 0; i < 160; i++) begin
            for (int j = 0; j < 160; j++) begin
                pred_memb[i][j] = pred[i][j];
            end
        end
        memb_pred_en = 1'b1;
    endfunction

    // optional wait argument, since check_memb can typically happen at the same time as check_fm
    task automatic check_memb(int dim=160, int out_ch = 16, layer_name_t layer, int wait_layer = 0);
        automatic logic error = 0;
        int offset;
    
        // wait for layer count to change
        if (wait_layer == 1)
            @(layer_count);
    
        if (memb_pred_en) begin
            $display($sformatf("Time: %t, Beginning predicted membrane check for layer: %0s", $time, layer.name()));

            case(layer) 
                LAYER_M1: offset = 0;
                LAYER_M2: offset = 40*40;
                LAYER_M3: offset = 40*40*2;
                LAYER_M4: offset = 40*40*3;
                default: offset = 0;
            endcase


            for (int ch = 0; ch < out_ch; ch++) begin
                for (int i = 0; i < dim; i++) begin
                    for (int j = 0; j < dim; j++) begin
                        int x = j;
                        int y = i;
                        int addr = y * dim + x + offset;
    
                        act_memb[y][x][MEMB_WIDTH*ch +: MEMB_WIDTH] = read_memb(ch, addr);
    
                    end
                end
            end

            for (int ch = 0; ch < out_ch; ch++) begin
                for (int j = 0; j < dim; j++) begin
                    for (int i = 0; i < dim; i++) begin
                        if ($signed(act_memb[i][j][MEMB_WIDTH*ch +: MEMB_WIDTH]) !== $signed(pred_memb[i][j][MEMB_WIDTH*ch +: MEMB_WIDTH])) begin
                            $display($sformatf("Time: %t, Error in predicted membrane comparison at y, x (%0d, %0d) channel %0d, act: %0d, pred: %0d", $time, i, j, ch, $signed(act_memb[i][j][MEMB_WIDTH*ch +: MEMB_WIDTH]), $signed(pred_memb[i][j][MEMB_WIDTH*ch +: MEMB_WIDTH])));
                            error = 1;
                            check_error = 1;
                        end
                    end
                end
            end

            if (!error) begin
                $display($sformatf("Time: %t, Predicted membrane check for layer: %0s PASSED", $time, layer.name()));
            end else begin
                $display($sformatf("Time: %t, Predicted membrane check for layer: %0s FAILED", $time, layer.name()));
            end
    
            memb_pred_en = 0;
        end 
    endtask : check_memb













     function automatic logic read_fm(input int ch, input int addr, input int idx, input string loc = "fm_mem");
        logic [FM_DWIDTH-1:0] data;
        if (loc == "fm_mem") begin
            case(ch) 
                0 : data = `FM_MEM(0)[addr];
                1 : data = `FM_MEM(1)[addr];
                2 : data = `FM_MEM(2)[addr];
                3 : data = `FM_MEM(3)[addr];
                4 : data = `FM_MEM(4)[addr];
                5 : data = `FM_MEM(5)[addr];
                6 : data = `FM_MEM(6)[addr];
                7 : data = `FM_MEM(7)[addr];
                8 : data = `FM_MEM(8)[addr];
                9 : data = `FM_MEM(9)[addr];
                10 : data = `FM_MEM(10)[addr];
                11 : data = `FM_MEM(11)[addr];
                12 : data = `FM_MEM(12)[addr];
                13 : data = `FM_MEM(13)[addr];
                14 : data = `FM_MEM(14)[addr];
                15 : data = `FM_MEM(15)[addr];
                default: data = `FM_MEM(0)[addr];
            endcase

            //$display($sformatf("Reading FM mem for channel %d at addr %d, idx %d: data %d", ch, addr, idx, data));
            return data[idx];
        end else if (loc == "flow_head") begin
            data = `FLOW_HEAD_FM_MEM[addr];
 
            return data[ch];
        end
     endfunction

     // mem [0:8191][207:0]
     function automatic logic signed [SUM_WIDTH-1:0] read_sum(input int ch, input int addr);
        logic [SUM_DWIDTH-1:0] data;

        data = `SUM_MEM[addr];

        return $signed(data[SUM_WIDTH*ch +: SUM_WIDTH]);

        //$display($sformatf("Reading sum for channel %d at addr %d: data %d", ch, addr, data));
     endfunction

     // mem [0:8191][207:0]
     function automatic logic signed [MEMB_WIDTH-1:0] read_memb(input int ch, input int addr);
        logic [MEMB_DWIDTH-1:0] data;

        data = `MEMBRANE_MEM[addr];

        return $signed(data[MEMB_WIDTH*ch +: MEMB_WIDTH]);

        //$display($sformatf("Reading memb for channel %d at addr %d: data %d", ch, addr, data));
     endfunction

    // wait until the start of the layer
    // use to check feature map output of previous layer
    task wait_layer_start (layer_name_t target_layer);
        // use state to tell when done
        fork
        wait (layer_count == target_layer);
        begin
            #(2 * 1ms);
            $display($sformatf("Time: %t, ERROR: wait_layer_start timeout for layer %d", $time, target_layer));
        end
        join_any
        disable fork;
    endtask

    // wait until the sum has been accumulated (start of readout)
    // use to check sum output of layer
    task wait_sum_done ();
        // use state to tell when done
        fork
        wait (state_sum == SUM_READOUT_80 || state_sum == SUM_READOUT_40);
        begin
            #(2 * 1ms);
            $display($sformatf("Time: %t, ERROR: wait_sum_done timeout", $time));
        end
        join_any
        disable fork;
    endtask

    task wait_fh_done();
        fork
        wait (state_top == TOP_IDLE);
        begin
            #(2 * 1ms);
            $display($sformatf("Time: %t, ERROR: wait_fh_done timeout", $time));
        end
        join_any
        disable fork;
    endtask

    function automatic logic get_check_error();
        return check_error;
    endfunction







    // Flow head out

    logic signed [MEMB_I-1:0] pred_fh_uv_m0shift [2][320][320] = '{default: 0}; // channel, y, x
    logic fh_input_fm [320][320] = '{default: 0};
    logic uv_pred_en = 0;
    logic fh_error = 0;
    
    logic [       8:0] fh_x;
    logic [       8:0] fh_y;
    logic signed [MEMB_I-1:0] fh_u;
    logic signed [MEMB_I-1:0] fh_v;
    logic              fh_valid;
    logic [8:0] fh_current_y = 0;
    

    logic fh_done_proc_out;
    initial begin
        force fh_x = `FLOW_HEAD_TOP_0.out_x;
        force fh_y = `FLOW_HEAD_TOP_0.out_y;
        force fh_u = `FLOW_HEAD_TOP_0.out_u;
        force fh_v = `FLOW_HEAD_TOP_0.out_v;
        force fh_valid = `FLOW_HEAD_TOP_0.out_valid;

        force fh_done_proc_out = `FLOW_HEAD_TOP_0.done_proc_out;
    end


    function automatic void set_predicted_uv_sum_m0shift(input logic signed [MEMB_I-1:0] pred_sum_m0shift[2][320][320], input logic signed [MEMB_I-1:0] input_fm [320][320] );
    
        for (int i = 0; i < 320; i++) begin
            for (int j = 0; j < 320; j++) begin
                pred_fh_uv_m0shift[0][i][j] = pred_sum_m0shift[0][i][j];
                pred_fh_uv_m0shift[1][i][j] = pred_sum_m0shift[1][i][j];

                fh_input_fm[i][j] = input_fm[i][j][0]; // bit 0
            end
        end
        uv_pred_en = 1'b1;
    endfunction


    always_ff @(posedge aclk) begin
        // check if valid output is correct
        if (uv_pred_en && fh_valid) begin
            automatic logic signed [MEMB_I-1:0] u_exp = pred_fh_uv_m0shift[0][fh_y][fh_x];
            automatic logic signed [MEMB_I-1:0] v_exp = pred_fh_uv_m0shift[1][fh_y][fh_x];

            if (fh_input_fm[fh_y][fh_x] == 0) begin // if fm value is 0, we should not have a valid output, even if the values match
                $display($sformatf("Time: %t, Error in predicted flow head output at y, x (%0d, %0d), exp u: %0d got u: %0d, exp v: %0d got v: %0d", $time, fh_y, fh_x, u_exp, fh_u, v_exp, fh_v));
                fh_input_fm[fh_y][fh_x] = 0; // clear fm value for this pixel after checking
                check_error = 1'b1;
                fh_error = 1'b1;
            end else if (fh_u !== u_exp || fh_v !== v_exp) begin
                $display($sformatf("Time: %t, Unexpected predicted flow head output at y, x (%0d, %0d), got u: %0d, v: %0d", $time, fh_y, fh_x, fh_u, fh_v));
                check_error = 1'b1;
                fh_error = 1'b1;
            end else begin
                fh_input_fm[fh_y][fh_x] = 0; // clear fm value for this pixel after checking
            end
        end


        // check that we see all expected outputs for a line once we move on to the next line or are done
        if (uv_pred_en) begin
            // since fm reader technically reads line by line this should work
            if (fh_y != fh_current_y || fh_done_proc_out) begin
                while (fh_current_y < fh_y) begin
                    for (int j = 0; j < 320; j++) begin
                        if (fh_input_fm[fh_current_y][j] == 1) begin
                            if(pred_fh_uv_m0shift[0][fh_current_y][j] != 0 || pred_fh_uv_m0shift[1][fh_current_y][j] != 0) begin // this only checks non zero flow
                                $display($sformatf("Time: %t, Error: Expected flow head output at y, x (%0d, %0d) was not seen in output stream, expected u: %0d, v: %0d", $time, fh_current_y, j, pred_fh_uv_m0shift[0][fh_current_y][j], pred_fh_uv_m0shift[1][fh_current_y][j]));
                                check_error = 1'b1;
                                fh_error = 1'b1;
                            end 
                        end
                    end
                    fh_current_y = fh_current_y + 1;
                end
            end
        end

        if (uv_pred_en && fh_done_proc_out) begin
            if (fh_error) begin
                $display($sformatf("Time: %t, Predicted flow head output check FAILED", $time));
                fh_error = 0; // reset for next time
                uv_pred_en = 1'b0;
                fh_current_y = 0;
            end else begin
                $display($sformatf("Time: %t, Predicted flow head output check PASSED", $time));
                fh_error = 0; // reset for next time
                uv_pred_en = 1'b0;
                fh_current_y = 0;
            end

        end

    end






endinterface

`endif
