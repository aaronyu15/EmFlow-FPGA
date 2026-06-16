`ifndef EVT_AGENT_MONITOR
`define EVT_AGENT_MONITOR

class evt_agent_monitor extends uvm_monitor;
 
  
  `uvm_component_utils(evt_agent_monitor)

  
  virtual evt_agent_interface m_evt_if;
  
  
  uvm_analysis_port #(evt_agent_transaction) mon2sb_port;
  
  
  evt_agent_transaction act_trans;
  
  
  function new (string name, uvm_component parent);
    super.new(name, parent);
    act_trans = new();
    mon2sb_port = new("mon2sb_port", this);
  endfunction : new
  
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual evt_agent_interface)::get(this, "", "m_evt_if", m_evt_if))
       `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".m_evt_if"});
  endfunction: build_phase
  
  
  virtual task run_phase(uvm_phase phase);
    //forever begin
    //  collect_trans();
    //  mon2sb_port.write(act_trans);
    //end
  endtask : run_phase
  
  
  task collect_trans();
    wait(m_evt_if.aresetn);
    @(m_evt_if.cb);

  endtask

endclass : evt_agent_monitor

`endif
