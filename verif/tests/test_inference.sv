`ifndef TEST_INFERENCE
`define TEST_INFERENCE


class test_inference extends test_basic;

    `uvm_component_utils(test_inference)


    function new(string name = "test_inference", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new


    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Start of build_phase"), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("End of build_phase"), UVM_LOW);
    endfunction : build_phase



    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Start of connect_phase"), UVM_LOW);

        `uvm_info(get_type_name(), $sformatf("End of connect_phase"), UVM_LOW);
    endfunction : connect_phase

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Start of end_of_elaboration_phase"), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("End of end_of_elaboration_phase"), UVM_LOW);
    endfunction : end_of_elaboration_phase


    virtual function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Start of start_of_simulation_phase"), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("End of start_of_simulation_phase"), UVM_LOW);
    endfunction : start_of_simulation_phase


    task reset_phase(uvm_phase phase);
        super.reset_phase(phase);
        phase.raise_objection(this);
        `uvm_info(get_type_name(), $sformatf("Start of reset_phase"), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("End of reset_phase"), UVM_LOW);
        phase.drop_objection(this);
    endtask : reset_phase


    task main_phase(uvm_phase phase);
        string frame_path;
        string base_path = "./debug_tests";
        int timestep = 0;
        string debug_src_path = {base_path, "/", debug_src};
        string timestep_src_path;
        time start_time, end_time;
        real time_ms[5];

        //y  x
        logic [15:0] exp_fm[160][160];
        logic [SUM_DWIDTH-1:0] exp_sum[160][160];
        logic [MEMB_DWIDTH-1:0] exp_memb[160][160];
        logic signed [MEMB_I-1:0] exp_flow[2][320][320];
        logic signed [MEMB_I-1:0] input_int[2][320][320];  // shape to match with existing function, only channel 0 is used
        int buf_sel;

        int dim;
        int out_ch;

        layer_name_t layer_count;

        phase.raise_objection(this);
        `uvm_info(get_type_name(), $sformatf("Start of main_phase"), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("Starting test with debug source: %s", debug_src_path), UVM_LOW);

        // Start 
        `m_snn_if.en <= 1;
        buf_sel = 0;

        for (int t = 0; t < C_NUM_TIMESTEPS; t = t + 1) begin : timestep_loop
            timestep   = t;
            timestep_src_path = {debug_src_path, "/", $sformatf("%0d", timestep)};
            layer_count = LAYER_E1;

            `uvm_info(get_type_name(), $sformatf("========================= PROCESSING TIMESTEP: %0d =========================", timestep), UVM_LOW);

            get_input_int(.src_path(timestep_src_path), .layer(layer_count), .input_int(input_int), .print_debug(0));
            `m_snn_if.set_buffer_frame(input_int[0], buf_sel);
            `uvm_info(get_type_name(), $sformatf("Loading frame into buffer %0d from %s", buf_sel, timestep_src_path), UVM_LOW);
            buf_sel = (buf_sel + 1) % 2; // alternate buffer for next time

            #(1ns * 100);
            start_time = $time;

            `m_snn_if.trigger_buf_swap();  // this triggers the run condition
            `m_snn_if.wait_layer_start(LAYER_E1);


            // does not include flow head
            for (int i = 0; i < C_NUM_LAYERS; i = i + 1) begin : layer_loop
                case (layer_count)
                    LAYER_E1: begin
                        dim = 160;
                        out_ch = 8;
                    end
                    LAYER_E2: begin
                        dim = 80;
                        out_ch = 8;
                    end
                    LAYER_M1: begin
                        dim = 40;
                        out_ch = 16;
                    end
                    LAYER_M2: begin
                        dim = 40;
                        out_ch = 16;
                    end
                    LAYER_M3: begin
                        dim = 40;
                        out_ch = 16;
                    end
                    LAYER_M4: begin
                        dim = 40;
                        out_ch = 16;
                    end
                    LAYER_D1: begin
                        dim = 40;
                        out_ch = 8;
                    end
                endcase

                // sum
                if (layer_count != LAYER_E1) begin
                    `uvm_info(get_type_name(), $sformatf("Testing layer %0s sum map output", layer_count.name()), UVM_LOW);
                    get_exp_sum_out(.src_path(timestep_src_path), .layer(layer_count), .exp_sum(exp_sum), .print_debug(0));
                    `uvm_info(get_type_name(), $sformatf("Setting expected sum for layer: %0s", layer_count.name()), UVM_LOW);
                    `m_snn_if.set_predicted_sum(exp_sum);
                    `m_snn_if.check_sum(.dim(dim), .out_ch(out_ch), .layer(layer_count));
                end

                // fm
                `uvm_info(get_type_name(), $sformatf("Testing layer %0s fm map output", layer_count.name()), UVM_LOW);
                get_exp_fm_out(.src_path(timestep_src_path), .layer(layer_count), .exp_fm(exp_fm), .print_debug(0));
                `uvm_info(get_type_name(), $sformatf("Setting predicted fm for layer: %0s", layer_count.name()), UVM_LOW);
                `m_snn_if.set_predicted_fm(exp_fm);

                if (layer_count != LAYER_D1) begin  // D1 goes into flow head
                    `m_snn_if.check_fm(.dim(dim), .out_ch(out_ch), .layer(layer_count));
                end else begin
                    `m_snn_if.check_fm(.dim(dim), .out_ch(out_ch), .layer(layer_count), .loc("flow_head"));
                end

                // memb
                if (layer_count inside {LAYER_M1, LAYER_M2, LAYER_M3, LAYER_M4}) begin
                    `uvm_info(get_type_name(), $sformatf("Testing layer %0s memb map output", layer_count.name()), UVM_LOW);
                    get_exp_memb_out(.src_path(timestep_src_path), .layer(layer_count), .exp_memb(exp_memb), .print_debug(0));
                    `uvm_info(get_type_name(), $sformatf("Setting predicted membrane for layer: %0s", layer_count.name()), UVM_LOW);
                    `m_snn_if.set_predicted_memb(exp_memb);
                    `m_snn_if.check_memb(.dim(dim), .out_ch(out_ch), .layer(layer_count), .wait_layer(0));
                end

                layer_count = layer_count.next();
            end


            // check sum_m0_shift product for flow head
            get_flow_int(.src_path(timestep_src_path), .layer(layer_count), .exp_flow(exp_flow), .print_debug(0));
            get_input_int(.src_path(timestep_src_path), .layer(layer_count), .input_int(input_int), .print_debug(0));

            `uvm_info(get_type_name(), $sformatf("Setting predicted flow head int for layer: %0s", layer_count.name()), UVM_LOW);

            `m_snn_if.set_predicted_uv_sum_m0shift(exp_flow, input_int[0]);
            `m_snn_if.wait_fh_done();

            end_time = $time;

            `uvm_info(get_type_name(), $sformatf("Layer %0s processing time: %0t (%0.2f ms)", layer_count.name(), end_time - start_time, real'(end_time - start_time) / 1000000.0), UVM_LOW);

            time_ms[t] = real'(end_time - start_time) / 1000000.0;

            if (t == C_NUM_TIMESTEPS - 1) begin
                `uvm_info(get_type_name(), $sformatf("========================= COMPLETED ALL TIMESTEPS ========================="), UVM_LOW);
            end

        end

        `uvm_info(get_type_name(), $sformatf("TIMESTEP SUMMARY"), UVM_LOW);
        for (int i = 0; i < C_NUM_TIMESTEPS; i = i + 1) begin
            `uvm_info(get_type_name(), $sformatf("Timestep %0d processing time: %0.2f ms", i, time_ms[i]), UVM_LOW);
        end


        if (`m_snn_if.get_check_error()) begin
            `uvm_error(get_type_name(), "Test failed with errors in predicted vs actual comparison.")
            m_env.m_sb.error = 1;
        end else begin
            `uvm_info(get_type_name(), "Test passed with no errors in predicted vs actual comparison.", UVM_LOW)
        end

        #(200 * 1us);

        `uvm_info(get_type_name(), $sformatf("End of main_phase"), UVM_LOW)
        phase.drop_objection(this);
    endtask : main_phase



    virtual function void extract_phase(uvm_phase phase);
        super.extract_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Start of extract_phase"), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("End of extract_phase"), UVM_LOW)
    endfunction : extract_phase


    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Start of check_phase"), UVM_LOW)
        `uvm_info(get_type_name(), $sformatf("End of check_phase"), UVM_LOW)
    endfunction : check_phase


    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Start of report_phase"), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("End of report_phase"), UVM_LOW);
    endfunction : report_phase


    virtual function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Start of final_phase"), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("End of final_phase"), UVM_LOW);
    endfunction : final_phase





endclass : test_inference

`endif
