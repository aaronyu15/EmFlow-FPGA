`ifndef SEQ_PKG 
`define SEQ_PKG

package seq_pkg;

 import uvm_pkg::*;
 `include "uvm_macros.svh"
 `include "agent_defines.svh"

 import agent_pkg::*;
 import env_pkg::*;

 `include "evt_sequence.sv"

endpackage

`endif
