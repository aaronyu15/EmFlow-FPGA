# Makefile for Vivado Design Simulation (using XSim)
GREEN = \033[32m
YELLOW = \033[33m
RED = \033[31m
CYAN = \033[36m
RESET = \033[0m

# --- User Configuration ---
# Adjust these variables for your specific design
include Makefile_Auto.mk

# Vivado executable path. Change if vivado is not in your PATH or is a different version.
VIVADO := vivado

# Directory for simulation outputs (compiled libraries, waveforms, logs)
SIM_OUTPUT_DIR := output
SIM_WORK_DIR := $(SIM_OUTPUT_DIR)/work

# Top-level module of your Testbench
TESTBENCH_TOP_MODULE := tb_top
BD_NAME := kv260

# Simulation-specific Tcl script to run after elaboration (e.g., for force/release, breakpoints)
SIM_TCL_SCRIPT := cmd.tcl 

MODE ?= RTL
# --- Internal Variables (Generally no need to modify) ---

# Command aliases
XVLOG := xvlog
XVHDL := xvhdl
XELAB := xelab
XSIM := xsim

# Simulation logs and WDB file
COMPILE_LOG := $(SIM_OUTPUT_DIR)/compile.log
ELABORATE_LOG := $(SIM_OUTPUT_DIR)/elaborate.log


XVLOG_OPTS :=
XVLOG_OPTS += -sv 
#XVLOG_OPTS += -incr # Incremental analysis/elaboration
XVLOG_OPTS += -relax # Relax strict language rules
XVLOG_OPTS += -nolog
XVLOG_OPTS += -L uvm
#XVLOG_OPTS += -L axi_vip_v1_1_17 
XVLOG_OPTS += -L axi_vip_v1_1_13 
XVLOG_OPTS += -L smartconnect_v1_0 
#XVLOG_OPTS += -L zynq_ultra_ps_e_vip_v1_0_17  Manually compile to get rid of display statements
XVLOG_OPTS += -L xilinx_vip
XVLOG_OPTS += -L mipi_dphy_v4_3_11
XVLOG_OPTS += -L mipi_dsi2_rx_ctrl_v1_0_0
#XVLOG_OPTS += -L mipi_csi2_rx_ctrl_v1_0_10
XVLOG_OPTS += -L mipi_csi2_rx_ctrl_v1_0_8
XVLOG_OPTS += -L mipi_dsi_tx_ctrl_v1_0_9
XVLOG_OPTS += -L mipi_csi2_tx_ctrl_v1_0_6
XVLOG_OPTS += -L mipi_rx_phy_v1_0_0
XVLOG_OPTS += -L high_speed_selectio_wiz_v3_6_9
#XVLOG_OPTS += -L xlslice_v1_0_4
XVLOG_OPTS += -L xlslice_v1_0_2

ifeq ($(MODE), POST_SYNTH)
XVLOG_OPTS += -d POST_SYNTH
else ifeq ($(MODE), POST_IMPL)
XVLOG_OPTS += -d POST_IMPL
else
XVLOG_OPTS += -d RTL_SIM
endif

# REMOVE THIS
#XVLOG_OPTS += -d USE_2X_CLK

XVHDL_OPTS :=
#XVHDL_OPTS += --incr
XVHDL_OPTS += --relax
XVHDL_OPTS += -nolog

XELAB_OPTS :=
#XELAB_OPTS += -incr
XELAB_OPTS += -debug typical
XELAB_OPTS += -relax
XELAB_OPTS += -mt $(shell nproc)
XELAB_OPTS += -nolog
XELAB_OPTS += -timescale 1ns/1ps
XELAB_OPTS += -L axi_infrastructure_v1_1_0 
#XELAB_OPTS += -L axi_vip_v1_1_17 
XELAB_OPTS += -L axi_vip_v1_1_13 
#XELAB_OPTS += -L zynq_ultra_ps_e_vip_v1_0_17 Manually compile to get rid of display statements
XELAB_OPTS += -L xil_defaultlib 
XELAB_OPTS += -L lib_pkg_v1_0_4 
XELAB_OPTS += -L fifo_generator_v13_2_10 
XELAB_OPTS += -L lib_fifo_v1_0_19 
XELAB_OPTS += -L lib_srl_fifo_v1_0_4 
XELAB_OPTS += -L lib_cdc_v1_0_3 
XELAB_OPTS += -L axi_datamover_v5_1_33 
XELAB_OPTS += -L axi_sg_v4_1_18 
XELAB_OPTS += -L axi_dma_v7_1_32 
#XELAB_OPTS += -L generic_baseblocks_v2_1_2 
XELAB_OPTS += -L generic_baseblocks_v2_1_0 
#XELAB_OPTS += -L axi_register_slice_v2_1_31 
XELAB_OPTS += -L axi_register_slice_v2_1_27 
#XELAB_OPTS += -L axi_data_fifo_v2_1_30 
XELAB_OPTS += -L axi_data_fifo_v2_1_26 
#XELAB_OPTS += -L axi_crossbar_v2_1_32 
XELAB_OPTS += -L axi_crossbar_v2_1_28 
#XELAB_OPTS += -L axi_protocol_converter_v2_1_31 
XELAB_OPTS += -L axi_protocol_converter_v2_1_27 
XELAB_OPTS += -L axi_clock_converter_v2_1_30 
#XELAB_OPTS += -L blk_mem_gen_v8_4_8 
XELAB_OPTS += -L blk_mem_gen_v8_4_5 
#XELAB_OPTS += -L axi_dwidth_converter_v2_1_31 
XELAB_OPTS += -L axi_dwidth_converter_v2_1_27
XELAB_OPTS += -L proc_sys_reset_v5_0_15 
#XELAB_OPTS += -L xlconstant_v1_1_9 
XELAB_OPTS += -L xlconstant_v1_1_7 
XELAB_OPTS += -L smartconnect_v1_0 
#XELAB_OPTS += -L xlconcat_v2_1_6 
XELAB_OPTS += -L xlconcat_v2_1_4
XELAB_OPTS += -L uvm 
XELAB_OPTS += -L xilinx_vip 
XELAB_OPTS += -L unisims_ver 
XELAB_OPTS += -L unimacro_ver 
XELAB_OPTS += -L secureip 
XELAB_OPTS += -L xpm 
#XELAB_OPTS += -L mipi_dphy_v4_3_11
XELAB_OPTS += -L mipi_dphy_v4_3_5
XELAB_OPTS += -L mipi_dsi2_rx_ctrl_v1_0_0
#XELAB_OPTS += -L mipi_csi2_rx_ctrl_v1_0_10
XELAB_OPTS += -L mipi_csi2_rx_ctrl_v1_0_8
XELAB_OPTS += -L mipi_dsi_tx_ctrl_v1_0_9
XELAB_OPTS += -L mipi_csi2_tx_ctrl_v1_0_6
XELAB_OPTS += -L mipi_rx_phy_v1_0_0
#XELAB_OPTS += -L high_speed_selectio_wiz_v3_6_9
XELAB_OPTS += -L high_speed_selectio_wiz_v3_6_4
#XELAB_OPTS += -L xlslice_v1_0_4
XELAB_OPTS += -L xlslice_v1_0_2

# Assuming I ever do timing sims
ifeq ($(MODE), POST_SYNTH)
# XELAB_OPTS += -L simprims_ver
else ifeq ($(MODE), POST_IMPL)
# XELAB_OPTS += -L simprims_ver
endif


XELAB_OPTS += --snapshot ${TESTBENCH_TOP_MODULE} 
#xil_defaultlib.$(BD_NAME) xil_defaultlib.glbl 
#XELAB_OPTS += -L xil_defaultlib.glbl 

XELAB_OPTS += -log $(ELABORATE_LOG)

XSIM_OPTS :=
#XSIM_OPTS += -key {Behavioral:sim_1:Functional:$(BD_NAME)} 
XSIM_OPTS += -tclbatch $(SIM_TCL_SCRIPT) 

ifeq ($(MODE), RTL)
endif
XSIM_OPTS += -protoinst "$(BD_NAME)/xsim/protoinst_files/bd_130f.protoinst"  # Protocol analysis files
XSIM_OPTS += -protoinst "$(BD_NAME)/xsim/protoinst_files/$(BD_NAME).protoinst" 
ifeq ($(GUI), 1)
	XSIM_OPTS += -gui
endif

XSIM_PLUS_ARGS_LIST := 
ifneq ($(UVM_TESTNAME),)
	XSIM_PLUS_ARGS_LIST += UVM_TESTNAME=$(UVM_TESTNAME)
endif
ifneq ($(UVM_VERBOSITY),)
	XSIM_PLUS_ARGS_LIST += UVM_VERBOSITY=$(UVM_VERBOSITY)
endif
ifneq ($(DEBUG_SRC),)
	XSIM_PLUS_ARGS_LIST += DEBUG_SRC=$(DEBUG_SRC)
endif



#XSIM_PLUS_ARGS_LIST += UVM_TESTNAME=test_basic
#XSIM_PLUS_ARGS_LIST += UVM_VERBOSITY=LOW
SIM_STRING := $(UVM_TESTNAME)_$(UVM_VERBOSITY)_$(DEBUG_SRC)
SIM_RUN_LOG := $(SIM_OUTPUT_DIR)/simulate_$(SIM_STRING).log
SIM_WDB := $(SIM_OUTPUT_DIR)/simulate_$(SIM_STRING).wdb

XSIM_OPTS += -log $(SIM_RUN_LOG)
XSIM_OPTS += -wdb $(SIM_WDB)

XSIM_PLUS_ARGS := $(foreach arg, $(XSIM_PLUS_ARGS_LIST), -testplusarg $(arg))


#ifeq ($(MODE), POST_SYNTH)
#	XELAB_OPTS += -sdftyp ../outputs/post_synth/post_synth.sdf
#	XELAB_OPTS += -sdfroot top_wrapper
#else ifeq ($(MODE), POST_IMPL)
#	XELAB_OPTS += -sdftyp ../outputs/main.sdf
#	XELAB_OPTS += -sdfroot top_wrapper
#endif

# --- Targets ---

.PHONY: all compile elaborate simulate wdb clean help 

all: simulate ## Default target: runs the simulation

compile: $(SIM_OUTPUT_DIR)/.compiled ## Compiles all RTL and Testbench sources

elaborate: $(SIM_OUTPUT_DIR)/.elaborated ## Compiles all RTL and Testbench sources

# Marker file for compilation completion
$(SIM_OUTPUT_DIR)/.compiled: $(ALL_COMPILED_SOURCES)  
	@echo -e "$(GREEN)--- Compiling RTL and Testbench Sources ---$(RESET)";
	@$(RM) $(COMPILE_LOG)
	@mkdir -p $(SIM_WORK_DIR)
	@missing=0; \
	for touch_file in $(ALL_COMPILED_SOURCES); do \
		if [ ! -f "$$touch_file" ]; then \
			echo -e "$(RED)Missing: $$touch_file (compilation may have failed)$(RESET)"; \
			missing=1; \
		fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
		echo -e "$(RED)Error: Some source files failed to compile. Check $(COMPILE_LOG)$(RESET)"; \
		exit 1; \
	else \
		echo -e "$(GREEN)--- Compilation Complete. Check $(COMPILE_LOG) ---$(RESET)"; \
		touch $@; \
	fi

$(SIM_OUTPUT_DIR)/.elaborated: $(SIM_OUTPUT_DIR)/.compiled ## Elaborates the design
	@$(RM) $(ELABORATE_LOG)
	@mkdir -p $(SIM_WORK_DIR)
	@echo -e "$(GREEN)--- Elaborating RTL and Testbench Sources ---$(RESET)";
	@echo $(XELAB) $(XELAB_OPTS) $(TESTBENCH_TOP_MODULE) glbl
	@set -o pipefail; $(XELAB) $(XELAB_OPTS) $(TESTBENCH_TOP_MODULE) glbl 2>&1 | tee -a $(ELABORATE_LOG) | \
		sed -e 's/^\(WARNING: \[[^]]*\]\)/$(YELLOW)\1$(RESET)/g' \
		    -e 's/^\(ERROR: \[[^]]*\]\)/$(RED)\1$(RESET)/g' \
		    -e 's/^\(INFO: \[[^]]*\]\)/$(CYAN)\1$(RESET)/g'; \
	if [ $${PIPESTATUS[0]} -eq 0 ]; then \
		echo -e "$(GREEN)--- Elaboration Complete. Check $(ELABORATE_LOG) ---$(RESET)"; \
		touch $@; \
	else \
		echo -e "$(RED)Error: Failed to Elaborate$(RESET)"; \
		exit 1; \
	fi

sim: $(SIM_OUTPUT_DIR)/.elaborated $(SIM_OUTPUT_DIR)/.compiled ## Runs the simulation
	@echo -e "$(GREEN)--- Running Simulation ---$(RESET)"
	@$(RM) $(SIM_RUN_LOG) $(SIM_WDB)
	$(XSIM) $(XSIM_OPTS) $(TESTBENCH_TOP_MODULE) $(XSIM_PLUS_ARGS)
	@echo -e "$(GREEN)--- Simulation Complete. Check $(SIM_RUN_LOG) ---$(RESET)"

clean: ## Cleans up all generated simulation files
	@echo -e "$(YELLOW)--- Cleaning up simulation files ---$(RESET)"
	$(RM) -rf $(SIM_OUTPUT_DIR) $(SIM_WORK_DIR)
	$(RM) -rf xsim* xelab.pb xvlog* xvhdl* tr_db.log $(SIM_WORK_DIR)* .Xil xsim.ini vivado_pid* *.wdb
	@echo -e "$(YELLOW)--- Simulation Clean Complete ---$(RESET)"

gui:
	$(VIVADO) -mode gui -nojournal -nolog


help: ## Displays this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'