`ifndef ENV
`define ENV

class env extends uvm_env;
 
  `uvm_component_utils(env)
  
  evt_agent m_evt_agent;
  snn_agent m_snn_agent;
  scoreboard  m_sb;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new
  
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_evt_agent = evt_agent::type_id::create("m_evt_agent", this);
    m_snn_agent = snn_agent::type_id::create("m_snn_agent", this);
    m_sb = scoreboard::type_id::create("m_sb", this);
  endfunction : build_phase
  
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    m_evt_agent.m_monitor.mon2sb_port.connect(m_sb.mon2sb_export);
  endfunction : connect_phase











endclass : env

`endif




