`ifndef SNN_AGENT_MONITOR
`define SNN_AGENT_MONITOR

class snn_agent_monitor extends uvm_monitor;

    `uvm_component_utils(snn_agent_monitor)


    virtual snn_agent_interface m_snn_if;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new


    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual snn_agent_interface)::get(this, "", "m_snn_if", m_snn_if)) `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".m_snn_if"});
    endfunction : build_phase


    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);


        forever begin
            @(posedge m_snn_if.aclk);

        end
    endtask : run_phase


    task collect_trans();

    endtask

endclass : snn_agent_monitor

`endif
