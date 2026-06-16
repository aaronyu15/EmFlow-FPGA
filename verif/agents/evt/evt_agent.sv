`ifndef EVT_AGENT
`define EVT_AGENT

class evt_agent extends uvm_agent;
  
  `uvm_component_utils(evt_agent)
  
  evt_agent_driver    m_driver;
  evt_agent_sequencer m_sequencer;
  evt_agent_monitor   m_monitor;
  
  
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_driver = evt_agent_driver::type_id::create("m_driver", this);
    m_sequencer = evt_agent_sequencer::type_id::create("m_sequencer", this);
    m_monitor = evt_agent_monitor::type_id::create("m_monitor", this);
  endfunction : build_phase
  
  
  function void connect_phase(uvm_phase phase);
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
  endfunction : connect_phase


  virtual task run_phase(uvm_phase phase);
    `uvm_info(get_type_name(), $sformatf("Running agent"), UVM_LOW)


    endtask : run_phase
 
endclass : evt_agent

`endif
