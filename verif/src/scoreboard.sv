`ifndef SCOREBOARD
`define SCOREBOARD

class scoreboard extends uvm_scoreboard;

    `uvm_component_utils(scoreboard)

    uvm_analysis_export #(evt_agent_transaction)   mon2sb_export;
    uvm_tlm_analysis_fifo #(evt_agent_transaction) mon2sb_export_fifo;
    evt_agent_transaction                          exp_trans,              act_trans;
    evt_agent_transaction                          exp_trans_fifo     [$], act_trans_fifo[$];
    bit                                            error = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new


    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon2sb_export = new("mon2sb_export", this);
        mon2sb_export_fifo = new("mon2sb_export_fifo", this);
    endfunction : build_phase


    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        mon2sb_export.connect(mon2sb_export_fifo.analysis_export);
    endfunction : connect_phase


    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
        forever begin
            mon2sb_export_fifo.get(act_trans);
            if (act_trans == null) $stop;
            act_trans_fifo.push_back(act_trans);
        end

    endtask




    function void report_phase(uvm_phase phase);
        if (error == 0) begin
            `uvm_info(get_type_name(), "-------------------------------------------", UVM_LOW);
            `uvm_info(get_type_name(), "------------ TEST CASE PASSED -------------", UVM_LOW);
            `uvm_info(get_type_name(), "-------------------------------------------", UVM_LOW);
        end else begin
            `uvm_info(get_type_name(), "-------------------------------------------", UVM_LOW);
            `uvm_info(get_type_name(), "------------ TEST CASE FAILED -------------", UVM_LOW);
            `uvm_info(get_type_name(), "-------------------------------------------", UVM_LOW);
        end
    endfunction
endclass : scoreboard

`endif
