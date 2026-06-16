`ifndef TEST_MMAP_REG
`define TEST_MMAP_REG


class test_mmap_reg extends test_basic;

    `uvm_component_utils(test_mmap_reg)

    evt_sequence       seq;

    function new(string name = "test_mmap_reg", uvm_component parent = null);
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
        logic [39:0] snn_addr = 40'hA003_0000;
        logic [127:0] rd_data;

        logic [1:0] resp;
        phase.raise_objection(this);
        `uvm_info(get_type_name(), $sformatf("Start of main_phase"), UVM_LOW);

        `m_snn_if.disable_forces();  // make sure forces are disabled before we start the test

        seq = evt_sequence::type_id::create("seq");

        fork
            seq.start(m_env.m_evt_agent.m_sequencer);
        join_none

        // Start 

        // check the debug register
        m_zynq_api.read_data(.start_addr(snn_addr + 4*12), .rd_size(4), .rd_data(rd_data), .response(resp));
        `uvm_info(get_type_name(), $sformatf("Read from SNN debug register: 0x%08h, response: %0d", rd_data, resp), UVM_LOW);
        if (rd_data != 32'hDEAD_BEEF) begin
            `uvm_error(get_type_name(), $sformatf("Unexpected value read from SNN debug register: 0x%08h", rd_data))
            m_env.m_sb.error = 1;
        end else begin
            `uvm_info(get_type_name(), $sformatf("Successfully read expected value from SNN debug register: 0x%08h", rd_data), UVM_LOW)
        end


        // check zeroes in other debug registers
        for (int i = 1; i < 12; i++) begin
            m_zynq_api.read_data(.start_addr(snn_addr + 4*i), .rd_size(4), .rd_data(rd_data), .response(resp));

            `uvm_info(get_type_name(), $sformatf("Read from SNN debug register %0d: 0x%08h, response: %0d", i, rd_data, resp), UVM_LOW);
            if (rd_data != 32'h0) begin
                `uvm_error(get_type_name(), $sformatf("Unexpected value read from SNN debug register %0d: 0x%08h", i, rd_data))
                m_env.m_sb.error = 1;
            end else begin
                `uvm_info(get_type_name(), $sformatf("Successfully read expected value from SNN debug register %0d: 0x%08h", i, rd_data), UVM_LOW)
            end
        end

        // enable register
        `uvm_info(get_type_name(), $sformatf("Writing to enable register"), UVM_LOW)
        m_zynq_api.write_data(.start_addr(snn_addr), .wr_size(4), .wr_data(32'h1), .response(resp));
    

        // wait some time
        #(1 * 1us);

        `uvm_info(get_type_name(), $sformatf("Triggering buffer swap"), UVM_LOW)
        `m_snn_if.trigger_buf_swap();  // this triggers the run condition

        #(100 * 1us);

        // check zeroes in other debug registers
        for (int i = 1; i < 12; i++) begin
            m_zynq_api.read_data(.start_addr(snn_addr + 4*i), .rd_size(4), .rd_data(rd_data), .response(resp));

            `uvm_info(get_type_name(), $sformatf("Read from SNN debug register %0d: 0x%08h, response: %0d", i, rd_data, resp), UVM_LOW);
            if (rd_data != 32'h0) begin
                `uvm_error(get_type_name(), $sformatf("Unexpected value read from SNN debug register %0d: 0x%08h", i, rd_data))
                m_env.m_sb.error = 1;
            end else begin
                `uvm_info(get_type_name(), $sformatf("Successfully read expected value from SNN debug register %0d: 0x%08h", i, rd_data), UVM_LOW)
            end
        end

        // write to enable counter.
        `uvm_info(get_type_name(), $sformatf("Enabling counters"), UVM_LOW)
        m_zynq_api.write_data(.start_addr(snn_addr), .wr_size(4), .wr_data(32'h5), .response(resp));

        // wait some time
        #(1 * 1ms);

        // pause enable counter
        `uvm_info(get_type_name(), $sformatf("Pausing counters"), UVM_LOW)
        m_zynq_api.write_data(.start_addr(snn_addr), .wr_size(4), .wr_data(32'h1), .response(resp));

        for (int i = 0; i < 13; i++) begin
            m_zynq_api.read_data(.start_addr(snn_addr + 4*i), .rd_size(4), .rd_data(rd_data), .response(resp));

            `uvm_info(get_type_name(), $sformatf("Read from SNN debug register %0d: 0x%08h, response: %0d", i, rd_data, resp), UVM_LOW);
        end

        #(10 * 1us);

        // enable enable counter
        `uvm_info(get_type_name(), $sformatf("Enabling counters"), UVM_LOW)
        m_zynq_api.write_data(.start_addr(snn_addr), .wr_size(4), .wr_data(32'h5), .response(resp));


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







endclass : test_mmap_reg

`endif
