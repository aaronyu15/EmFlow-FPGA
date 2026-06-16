`ifndef ENV_PKG
`define ENV_PKG

package env_pkg;

   import uvm_pkg::*;
   `include "uvm_macros.svh"

  import agent_pkg::*;
  import design_pkg::*;

  `include "scoreboard.sv"
  `include "env.sv"

endpackage

`endif


