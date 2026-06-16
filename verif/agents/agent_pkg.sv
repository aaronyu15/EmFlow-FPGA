`ifndef AGENT_PKG
`define AGENT_PKG

package agent_pkg;
 
   import uvm_pkg::*;
   import design_pkg::*;

   `include "uvm_macros.svh"


  `include "agent_defines.svh"
  `include "evt_agent_transaction.sv"
  `include "evt_agent_sequencer.sv"
  `include "evt_agent_driver.sv"
  `include "evt_agent_monitor.sv"
  `include "evt_agent.sv"


   `include "snn_agent_monitor.sv"
   `include "snn_agent.sv"

endpackage

`endif



