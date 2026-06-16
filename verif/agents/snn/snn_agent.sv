`ifndef SNN_AGENT
`define SNN_AGENT

class snn_agent extends uvm_agent;
  
  `uvm_component_utils(snn_agent)
  
  snn_agent_monitor   m_monitor;
  virtual snn_agent_interface m_snn_if;

  
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_monitor = snn_agent_monitor::type_id::create("m_monitor", this);
    if (!uvm_config_db#(virtual snn_agent_interface)::get(this, "", "m_snn_if", m_snn_if)) `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".m_snn_if"});
  endfunction : build_phase
  
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

  endfunction : connect_phase


  virtual task run_phase(uvm_phase phase);
    `uvm_info(get_type_name(), $sformatf("Running agent"), UVM_LOW)

    endtask : run_phase
 
endclass : snn_agent

`endif
