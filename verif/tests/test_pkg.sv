`ifndef TEST_PKG
`define TEST_PKG

package test_pkg;

 import uvm_pkg::*;
 `include "uvm_macros.svh"
 `include "agent_defines.svh"

 import env_pkg::*;
 import seq_pkg::*;

import zynq_bfm_pkg::*;
import design_pkg::*;

 `include "test_basic.sv"
`ifdef RTL_SIM 
 `include "test_inference.sv"
 `include "test_mmap_reg.sv"
 `include "test_dma.sv"
`endif

endpackage 

`endif





