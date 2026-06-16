`ifndef EVT_AGENT_SEQUENCER
`define EVT_AGENT_SEQUENCER

class evt_agent_sequencer extends uvm_sequencer#(evt_agent_transaction);
 
  `uvm_component_utils(evt_agent_sequencer)
 
  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction
   
endclass

`endif




