`ifndef TEST_BASIC
`define TEST_BASIC

class test_basic extends uvm_test;


    `uvm_component_utils(test_basic)
    env          m_env;
    evt_sequence seq;
    zynq_bfm_api m_zynq_api;

    string debug_src;


    function new(string name = "test_basic", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new



    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Start of build_phase"), UVM_LOW);

        m_env = env::type_id::create("m_env", this);

        if (!uvm_config_db#(zynq_bfm_api)::get(this, "*", "m_zynq_api", m_zynq_api)) begin
            `uvm_fatal(get_type_name(), "Failed to get m_zynq_api from uvm_config_db")
        end


        `uvm_info(get_type_name(), $sformatf("End of build_phase"), UVM_LOW);
    endfunction : build_phase



    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Start of connect_phase"), UVM_LOW);

        `uvm_info(get_type_name(), $sformatf("End of connect_phase"), UVM_LOW);
    endfunction : connect_phase

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        string plusarg, plusargs_pattern;

        // Always call super.end_of_elaboration_phase
        super.end_of_elaboration_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Start of end_of_elaboration_phase"), UVM_LOW);

        `uvm_info(get_type_name(), $sformatf("--------------------------------------------------"), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("              Test Summary Report                 "), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("--------------------------------------------------"), UVM_LOW);

        plusarg = "UVM_TESTNAME";
        if ($value$plusargs({$sformatf("%s", plusarg), "=%s"}, plusargs_pattern)) 
        `uvm_info(get_type_name(), $sformatf("%s = %s", plusarg, plusargs_pattern), UVM_LOW);

        plusarg = "UVM_VERBOSITY";
        if ($value$plusargs({$sformatf("%s", plusarg), "=%s"}, plusargs_pattern)) 
        `uvm_info(get_type_name(), $sformatf("%s = %s", plusarg, plusargs_pattern), UVM_LOW);

        plusarg = "DEBUG_SRC";
        if ($value$plusargs({$sformatf("%s", plusarg), "=%s"}, plusargs_pattern)) 
        `uvm_info(get_type_name(), $sformatf("%s = %s", plusarg, plusargs_pattern), UVM_LOW);
        debug_src = plusargs_pattern;


        `uvm_info(get_type_name(), $sformatf("End of end_of_elaboration_phase"), UVM_LOW);
    endfunction : end_of_elaboration_phase


    virtual function void start_of_simulation_phase(uvm_phase phase);
        super.start_of_simulation_phase(phase);
        `uvm_info(get_type_name(), $sformatf("Start of start_of_simulation_phase"), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("End of start_of_simulation_phase"), UVM_LOW);
    endfunction : start_of_simulation_phase


    task reset_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info(get_type_name(), $sformatf("Start of reset_phase"), UVM_LOW);
        //Reset the PL zynq_ultra_ps_e_0   Base_Zynq_MPSoC_zynq_ultra_ps_e_0_0
        m_zynq_api.por_srstb_reset(1'b1);
        #200;  // This delay depends on your clock frequency. It should be at least 16 clock cycles. 
        m_zynq_api.por_srstb_reset(1'b0);
        m_zynq_api.fpga_soft_reset(32'hF);
        #400;  // This delay depends on your clock frequency. It should be at least 16 clock cycles. 
        m_zynq_api.por_srstb_reset(1'b1);
        m_zynq_api.fpga_soft_reset(32'h0);

        //`m_snn_if.en <= 1;

        //seq = evt_sequence::type_id::create("seq");

        //fork
        //    seq.start(m_env.m_evt_agent.m_sequencer);
        //join_none

        //#(1 * 2ms);  // This delay depends on your clock frequency. It should be at least 16 clock cycles. 

        //`m_snn_if.trigger_buf_swap();  // this triggers the run condition

        //#(1 * 1s);

        // Set debug level info to off. For more info, set to 1.
        m_zynq_api.set_debug_level_info(0);
        m_zynq_api.set_stop_on_error(1);
        // Set minimum port verbosity. Change to 32'd400 for maximum.

        //m_zynq_api.pre_load_mem(2'b11, src_addr, 256 / 8);  // Write Random
        //m_zynq_api.pre_load_mem(2'b01, dst_addr, 256 / 8);  // Write zeroes), UVM_LOW);
        `uvm_info(get_type_name(), $sformatf("End of reset_phase"), UVM_LOW);
        phase.drop_objection(this);
    endtask : reset_phase


    task main_phase(uvm_phase phase);
        phase.raise_objection(this);
        `uvm_info(get_type_name(), $sformatf("Start of main_phase"), UVM_LOW);
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



    // get_exp_fm_out
    virtual function automatic void get_exp_fm_out(input string src_path, input layer_name_t layer, output logic [15:0] exp_fm[160][160], input int print_debug = 0);
        string fm_path;
        int num_in_ch;
        int num_out_ch;
        int out_dim;
        string layer_name;
        logic [SUM_DWIDTH-1:0] s[160][160];
        logic [MEMB_DWIDTH-1:0] m[160][160];
        logic signed [MEMB_I-1:0] fl[2][320][320];

        get_layer_info(layer, num_in_ch, num_out_ch, layer_name, out_dim);

        fm_path = {src_path, "/", layer_name, "/", "fm_out.mem"};
        `uvm_info(get_type_name(), $sformatf("Loading feature map output from %s", fm_path), UVM_LOW);

        parse_debug_file("fm", fm_path, exp_fm, s, m, fl, print_debug);

    endfunction : get_exp_fm_out

    // get_exp_sum_out
    virtual function automatic void get_exp_sum_out(input string src_path, input layer_name_t layer, output logic [SUM_DWIDTH-1:0] exp_sum[160][160], input int print_debug = 0);
        string sum_path;
        int num_in_ch;
        int num_out_ch;
        int out_dim;
        string layer_name;
        logic [15:0] f[160][160];
        logic [MEMB_DWIDTH-1:0] m[160][160];
        logic signed [MEMB_I-1:0] fl[2][320][320];

        get_layer_info(layer, num_in_ch, num_out_ch, layer_name, out_dim);

        sum_path = {src_path, "/", layer_name, "/", "sum.mem"};
        `uvm_info(get_type_name(), $sformatf("Loading output sum from %s", sum_path), UVM_LOW);

        parse_debug_file("sum", sum_path, f, exp_sum, m, fl, print_debug);
    endfunction : get_exp_sum_out


    // get_exp_memb_out
    virtual function automatic void get_exp_memb_out(input string src_path, input layer_name_t layer, output logic [MEMB_DWIDTH-1:0] exp_memb[160][160], input int print_debug = 0);
        string memb_path;
        int num_in_ch;
        int num_out_ch;
        int out_dim;
        string layer_name;
        logic [15:0] f[160][160];
        logic [SUM_DWIDTH-1:0] s[160][160];
        logic signed [MEMB_I-1:0] fl[2][320][320];

        get_layer_info(layer, num_in_ch, num_out_ch, layer_name, out_dim);

        memb_path = {src_path, "/", layer_name, "/", "memb_post.mem"};
        `uvm_info(get_type_name(), $sformatf("Loading output memb from %s", memb_path), UVM_LOW);

        parse_debug_file("memb", memb_path, f, s, exp_memb, fl, print_debug);
    endfunction : get_exp_memb_out

    // get_memb_in
    virtual function automatic void get_memb_in(input string src_path, input layer_name_t layer, output logic [MEMB_DWIDTH-1:0] init_memb[160][160], input int print_debug = 0);
        string memb_path;
        int num_in_ch;
        int num_out_ch;
        int out_dim;
        string layer_name;
        logic [15:0] f[160][160];
        logic [SUM_DWIDTH-1:0] s[160][160];
        logic signed [MEMB_I-1:0] fl[2][320][320];

        get_layer_info(layer, num_in_ch, num_out_ch, layer_name, out_dim);

        memb_path = {src_path, "/", layer_name, "/", "memb_pre.mem"};
        `uvm_info(get_type_name(), $sformatf("Loading input memb from %s", memb_path), UVM_LOW);

        parse_debug_file("memb", memb_path, f, s, init_memb, fl, print_debug);
    endfunction : get_memb_in

    // get_exp_sum_prod_out
    virtual function automatic void get_flow_int(input string src_path, input layer_name_t layer, output logic signed [MEMB_I-1:0] exp_flow[2][320][320], input int print_debug = 0);
        string flow_path;
        int num_in_ch;
        int num_out_ch;
        int out_dim;
        string layer_name;
        logic [15:0] f[160][160];
        logic [SUM_DWIDTH-1:0] s[160][160];
        logic [MEMB_DWIDTH-1:0] m[160][160];

        get_layer_info(layer, num_in_ch, num_out_ch, layer_name, out_dim);

        flow_path = {src_path, "/", "flow_int.mem"};
        `uvm_info(get_type_name(), $sformatf("Loading output flow from %s", flow_path), UVM_LOW);

        parse_debug_file("flow", flow_path, f, s, m, exp_flow, print_debug);
    endfunction : get_flow_int

    // get_exp_sum_prod_out
    virtual function automatic void get_input_int(input string src_path, input layer_name_t layer, output logic signed [MEMB_I-1:0] input_int[2][320][320], input int print_debug = 0);
        string flow_path;
        int num_in_ch;
        int num_out_ch;
        int out_dim;
        string layer_name;
        logic [15:0] f[160][160];
        logic [SUM_DWIDTH-1:0] s[160][160];
        logic [MEMB_DWIDTH-1:0] m[160][160];

        get_layer_info(layer, num_in_ch, num_out_ch, layer_name, out_dim);

        flow_path = {src_path, "/", "input_int.mem"};
        `uvm_info(get_type_name(), $sformatf("Loading input int from %s", flow_path), UVM_LOW);

        parse_debug_file("input", flow_path, f, s, m, input_int, print_debug);
    endfunction : get_input_int


    virtual function automatic void parse_debug_file(input string data_type, input string file_path, output logic [15:0] fm[160][160], output logic [SUM_DWIDTH-1:0] sum[160][160], output logic [MEMB_DWIDTH-1:0] memb[160][160], output logic signed [MEMB_I-1:0] flow[2][320][320],
                                                     input int print_debug = 0);

        int fd;
        int ch, x, y, v;

        fd = $fopen(file_path, "r");

        if (fd == 0) begin
            `uvm_error(get_type_name(), $sformatf("Failed to open debug file: %s", file_path))
            return;
        end

        while (!$feof(
            fd
        )) begin
            if ($fscanf(fd, "ch=%d, x=%d, y=%d, v=%d", ch, x, y, v) != 4) begin
                `uvm_error(get_type_name(), $sformatf("Failed to parse line in debug file"))
                continue;
            end

            case (data_type)
                "fm": begin
                    fm[y][x][ch] = v;
                end
                "sum": begin
                    sum[y][x][ch*SUM_WIDTH+:SUM_WIDTH] = v;
                end
                "memb": begin
                    memb[y][x][ch*MEMB_WIDTH+:MEMB_WIDTH] = v;
                end
                "flow": begin
                    flow[ch][y][x] = v;
                end
                "input": begin
                    flow[ch][y][x] = v;
                end
                default: `uvm_error(get_type_name(), $sformatf("Invalid data type specified: %s", data_type))
            endcase

            if (print_debug) `uvm_info(get_type_name(), $sformatf("Parsed %s line from debug file - ch: %0d, y, x (%0d, %0d), v: %0d", data_type, ch, y, x, v), UVM_DEBUG);
        end
        $fclose(fd);

    endfunction : parse_debug_file




endclass : test_basic

`endif












