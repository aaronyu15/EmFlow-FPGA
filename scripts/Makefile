# Makefile for Non-Project Mode Vivado Flow
# Define colors as variables
ESC := $(shell printf '\033')
YELLOW := $(ESC)[33m
GREEN := $(ESC)[32m
RED := $(ESC)[31m
CYAN := $(ESC)[36m
RESET := $(ESC)[0m

SHELL := /bin/bash
VIVADO := vivado
VITIS := vitis
TCL_BUILD_SCRIPT := 00_build.tcl

#export DEVICE_PART 	:= xczu1cg-sbva484-1-e # ZUBoard part
export DEVICE_PART      := xck26-sfvc784-2LV-c
#export DEVICE_PART      :=  xczu3eg-sfvc784-2-e

#export BOARD_PART 		:= avnet-tria:zuboard_1cg:part0:1.2
export BOARD_PART 		:= xilinx.com:kv260_som:part0:1.4
#export BOARD_PART 		:= realdigital.org:aup-zu3-8gb:part0:1.0
export BD_NAME 	        := kv260
export RTL_TOP_MODULE 	:= top_wrapper

export PROJECT_DIR 			:= $(CURDIR)/..
export PROJECT_RTL_DIR 		:= $(PROJECT_DIR)/rtl
export PROJECT_VERIF_DIR 	:= $(PROJECT_DIR)/verif
export PROJECT_SCRIPT_DIR 	:= $(PROJECT_DIR)/scripts
export PROJECT_OUTPUT_DIR 	:= $(PROJECT_DIR)/outputs
export PROJECT_VIVADO_DIR 	:= $(PROJECT_DIR)/vivado_gui
export PROJECT_VITIS_DIR 	:= $(PROJECT_DIR)/vitis
export PROJECT_PTLNX_DIR 	:= $(PROJECT_DIR)/petalinux

export PROJECT_BD 			:= $(PROJECT_VIVADO_DIR)/myproj/project_1.srcs/sources_1/bd/$(BD_NAME)/$(BD_NAME).bd
export PROJECT_BD_WRAPPER 	:= $(PROJECT_VIVADO_DIR)/myproj/project_1.gen/sources_1/bd/$(BD_NAME)/hdl/$(BD_NAME)_wrapper.v
export PROJECT_HWH        	:= $(PROJECT_VIVADO_DIR)/myproj/project_1.gen/sources_1/bd/$(BD_NAME)/hw_handoff/$(BD_NAME).hwh
export PROJECT_XSA 			:= $(PROJECT_OUTPUT_DIR)/$(BD_NAME)_wrapper.xsa

export PROJECT_XSIM_DIR     := $(PROJECT_VERIF_DIR)/$(BD_NAME)/xsim
export PROJECT_VERIF_PRJ_F  := $(PROJECT_XSIM_DIR)/vlog.prj

export PROJECT_POST_SYNTH_DIR    := $(PROJECT_OUTPUT_DIR)/post_synth
export PROJECT_POST_OPT_DIR      := $(PROJECT_OUTPUT_DIR)/post_opt
export PROJECT_POST_PLACE_DIR    := $(PROJECT_OUTPUT_DIR)/post_place
export PROJECT_POST_PHYS_OPT_DIR := $(PROJECT_OUTPUT_DIR)/post_place_phys_opt
export PROJECT_POST_ROUTE_DIR    := $(PROJECT_OUTPUT_DIR)/post_route

export SAVE_OUTPUT_NAME 	:= main
export OUTPUT_HWH        	:= $(PROJECT_OUTPUT_DIR)/$(SAVE_OUTPUT_NAME).hwh
export OUTPUT_BIT        	:= $(PROJECT_OUTPUT_DIR)/$(SAVE_OUTPUT_NAME).bit

RTL_SOURCES := $(shell find $(PROJECT_RTL_DIR) -name "*.v" -or -name "*.sv")

GUI := 0
PYNQ := 0

# Define the path to the Vivado log file
VIVADO_SYNTH_LOG 	:= $(PROJECT_OUTPUT_DIR)/vivado_make_synth.log
VIVADO_IMPL_LOG 	:= $(PROJECT_OUTPUT_DIR)/vivado_make_impl.log
VIVADO_BIT_LOG 		:= $(PROJECT_OUTPUT_DIR)/vivado_make_bitstream.log
VIVADO_BD_LOG 		:= $(PROJECT_VIVADO_DIR)/vivado_make_bd.log
PTLNX_LOG 			:= $(PROJECT_PTLNX_DIR)/petalinux_make.log

VIVADO_ARGS :=

TCL_ARGS :=

TCL_ARGS += -part $(DEVICE_PART)
TCL_ARGS += -board $(BOARD_PART)
TCL_ARGS += -top $(RTL_TOP_MODULE)

SYNTH_TCL_ARGS := $(TCL_ARGS)
IMPL_TCL_ARGS  := $(TCL_ARGS)

VIVADO_BASE_CMD := $(VIVADO) -nojournal -nolog
VIVADO_ELAB_BASE_CMD := $(VIVADO_BASE_CMD) -mode batch -source $(TCL_BUILD_SCRIPT) -tclargs -run_mode elab $(SYNTH_TCL_ARGS) 
VIVADO_SYNTH_BASE_CMD := $(VIVADO_BASE_CMD) -mode batch -source $(TCL_BUILD_SCRIPT) -tclargs -run_mode synth $(SYNTH_TCL_ARGS) 
VIVADO_IMPL_BASE_CMD  := $(VIVADO_BASE_CMD) -mode batch -source $(TCL_BUILD_SCRIPT) -tclargs -run_mode impl $(IMPL_TCL_ARGS) 

VIVADO_ELAB_CMD := $(VIVADO_ELAB_BASE_CMD)
VIVADO_SYNTH_CMD := $(VIVADO_SYNTH_BASE_CMD)
VIVADO_IMPL_CMD  := $(VIVADO_IMPL_BASE_CMD)

VIVADO_SYNTH_GUI_CMD := 
VIVADO_IMPL_GUI_CMD  := 
POST_IMPL_CMDS :=

# Override GUI_MODE for _gui targets
ifeq ($(MAKECMDGOALS), synthesis_gui)
	GUI := 1
endif
ifeq ($(MAKECMDGOALS), implementation_gui)
	GUI := 1
endif


ifneq ($(GUI), 0)
	ifneq ($(filter synthesis synthesis_gui,$(MAKECMDGOALS)),)
		VIVADO_SYNTH_GUI_CMD := $(VIVADO_BASE_CMD) -mode batch -source $(TCL_BUILD_SCRIPT) -tclargs -run_mode synth_gui $(SYNTH_TCL_ARGS) 
	endif
	ifneq ($(filter implementation implementation_gui,$(MAKECMDGOALS)),)
		VIVADO_IMPL_GUI_CMD  := $(VIVADO_BASE_CMD) -mode batch -source $(TCL_BUILD_SCRIPT) -tclargs -run_mode impl_gui $(IMPL_TCL_ARGS) 
	endif
endif

ifneq ($(PYNQ), 0)
	POST_IMPL_CMDS := scp $(OUTPUT_BIT) xilinx@192.168.2.99:/home/xilinx/jupyter_notebooks/Bitstreams && scp $(OUTPUT_HWH) xilinx@192.168.2.99:/home/xilinx/jupyter_notebooks/Bitstreams
endif

VITIS_BASE_CMD := $(VITIS)


# --- Phony targets for dependencies ---
.PHONY: all synthesis implementation clean cleanest help vivado p-all p-setup p-config p-build p-boot implementation_gui synthesis_gui elaboration

all: bitstream ## Default target: builds the bitstream

bd : $(PROJECT_BD)

synthesis: $(PROJECT_POST_SYNTH_DIR)/post_synth.dcp ## Runs synthesis

synthesis_gui:
	$(VIVADO_SYNTH_GUI_CMD)

implementation: $(PROJECT_POST_ROUTE_DIR)/post_route.dcp ## Runs implementation

implementation_gui:
	$(VIVADO_IMPL_GUI_CMD)

vivado:
	$(VIVADO_BASE_CMD) $(PROJECT_VIVADO_DIR)/myproj/project_1.xpr

debug:
	$(VIVADO_BASE_CMD) $(PROJECT_VIVADO_DIR)/myproj/project_1.xpr -source $(TCL_BUILD_SCRIPT) -tclargs -run_mode hw_debug

vitis:
	$(VITIS_BASE_CMD) -w $(PROJECT_VITIS_DIR)

pynq: ## Cleans up output files
	@echo -e "$(GREEN)Copying files to PYNQ board...$(RESET)"
	@scp $(OUTPUT_BIT) xilinx@192.168.2.99:/home/xilinx/jupyter_notebooks/Bitstreams || \
		{ echo -e "$(RED)Error: Failed to copy $(OUTPUT_BIT)$(RESET)"; exit 1; }
	@scp $(OUTPUT_HWH) xilinx@192.168.2.99:/home/xilinx/jupyter_notebooks/Bitstreams || \
		{ echo -e "$(RED)Error: Failed to copy $(OUTPUT_HWH)$(RESET)"; exit 1; }
	@echo -e "$(GREEN)Copy complete.$(RESET)"

clean: ## Cleans up output files
	@echo "$(YELLOW)--- Cleaning up output files ---$(RESET)"
	@$(RM) -rf $(PROJECT_OUTPUT_DIR) clockInfo.txt .Xil
	@echo "$(YELLOW)Clean complete.$(RESET)"

cleanest: ## Cleans up all files including block diagram generated directory
	@echo "$(YELLOW)--- Cleaning up all project files ---$(RESET)"
	@$(RM) -rf $(PROJECT_OUTPUT_DIR) clockInfo.txt .Xil $(PROJECT_VIVADO_DIR)/myproj $(PROJECT_VIVADO_DIR)/.Xil $(PROJECT_VERIF_DIR)/$(BD_NAME) $(PROJECT_VERIF_DIR)/rtl_sources.f
	@$(RM) -rf $(PROJECT_OUTPUT_DIR) clockInfo.txt .Xil $(PROJECT_VIVADO_DIR)/myproj $(PROJECT_VIVADO_DIR)/.Xil $(PROJECT_VERIF_DIR)/$(BD_NAME) $(PROJECT_VERIF_DIR)/rtl_sources.f
	@echo "$(YELLOW)Clean complete.$(RESET)"

help: ## Displays this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(CYAN)m%-20s$(RESET)m %s\n", $$1, $$2}'

# Petalinux Targets
p-all: implementation
	$(MAKE) -C $(PROJECT_PTLNX_DIR) all 2>&1 | tee $(PTLNX_LOG)

p-setup: implementation
	$(MAKE) -C $(PROJECT_PTLNX_DIR) setup 2>&1 | tee $(PTLNX_LOG)

p-config: implementation
	$(MAKE) -C $(PROJECT_PTLNX_DIR) config 2>&1 | tee $(PTLNX_LOG)

p-build: implementation
	$(MAKE) -C $(PROJECT_PTLNX_DIR) build 2>&1 | tee $(PTLNX_LOG)

p-boot: implementation
	$(MAKE) -C $(PROJECT_PTLNX_DIR) boot 2>&1 | tee $(PTLNX_LOG)

p-boot-jtag: implementation
	$(MAKE) -C $(PROJECT_PTLNX_DIR) boot-jtag 2>&1 | tee $(PTLNX_LOG)

p-root: implementation
	$(MAKE) -C $(PROJECT_PTLNX_DIR) sysroot 2>&1 | tee $(PTLNX_LOG)

p-clean: implementation
	$(MAKE) -C $(PROJECT_PTLNX_DIR) clean

# --- Targets ---
elaboration: $(MAIN_TCL_SCRIPT) $(PROJECT_BD) $(RTL_SOURCES)
	@echo -e "$(GREEN)--- Running RTL Elaboration ---$(RESET)"
	@set -o pipefail; $(VIVADO_ELAB_CMD) 2>&1 | \
		sed -e 's/^\(WARNING: \[[^]]*\]\)/$(YELLOW)\1$(RESET)/g' \
		    -e 's/^\(ERROR: \[[^]]*\]\)/$(RED)\1$(RESET)/g' \
		    -e 's/^\(INFO: \[[^]]*\]\)/$(CYAN)\1$(RESET)/g'; \
	if [ $${PIPESTATUS[0]} -eq 0 ]; then \
		echo -e "$(GREEN)Elaboration complete.$(RESET)";\
	else \
		echo -e "$(RED)Error: Failed to Elaborate$(RESET)"; \
		exit 1; \
	fi

$(PROJECT_POST_SYNTH_DIR)/post_synth.dcp: $(MAIN_TCL_SCRIPT) $(PROJECT_BD) $(RTL_SOURCES)
	@echo -e "$(GREEN)--- Running Synthesis ---$(RESET)"
	@mkdir -p $(PROJECT_POST_SYNTH_DIR)
	@$(RM) $(VIVADO_SYNTH_LOG)
	@echo "$(VIVADO_SYNTH_CMD)" >> $(VIVADO_SYNTH_LOG)
	@set -o pipefail; $(VIVADO_SYNTH_CMD) 2>&1 | tee -a $(VIVADO_SYNTH_LOG) | \
		sed -e 's/^\(WARNING: \[[^]]*\]\)/$(YELLOW)\1$(RESET)/g' \
		    -e 's/^\(ERROR: \[[^]]*\]\)/$(RED)\1$(RESET)/g' \
		    -e 's/^\(INFO: \[[^]]*\]\)/$(CYAN)\1$(RESET)/g'; \
	if [ $${PIPESTATUS[0]} -eq 0 ]; then \
		echo -e "$(GREEN)Synthesis complete. Check $(VIVADO_SYNTH_LOG) for details.$(RESET)";\
	else \
		echo -e "$(RED)Error: Synthesis failed. Check $(VIVADO_SYNTH_LOG)$(RESET)"; \
		exit 1; \
	fi

$(PROJECT_POST_ROUTE_DIR)/post_route.dcp: $(PROJECT_POST_SYNTH_DIR)/post_synth.dcp $(MAIN_TCL_SCRIPT)
	@echo -e "$(GREEN)--- Running Implementation ---$(RESET)"
	@mkdir -p $(PROJECT_POST_OPT_DIR) $(PROJECT_POST_PLACE_DIR) $(PROJECT_POST_PHYS_OPT_DIR) $(PROJECT_POST_ROUTE_DIR)
	@$(RM) $(VIVADO_IMPL_LOG)
	@echo "$(VIVADO_IMPL_CMD)" >> $(VIVADO_IMPL_LOG)

	@set -o pipefail; $(VIVADO_IMPL_CMD) 2>&1 | tee -a $(VIVADO_IMPL_LOG) | \
		sed -e 's/^\(WARNING: \[[^]]*\]\)/$(YELLOW)\1$(RESET)/g' \
		    -e 's/^\(ERROR: \[[^]]*\]\)/$(RED)\1$(RESET)/g' \
		    -e 's/^\(INFO: \[[^]]*\]\)/$(CYAN)\1$(RESET)/g'; \
	if [ $${PIPESTATUS[0]} -eq 0 ]; then \
		echo -e "$(GREEN)Implementation complete. Check $(VIVADO_IMPL_LOG) for details.$(RESET)";\
	else \
		echo -e "$(RED)Error: Implementation failed. Check $(VIVADO_IMPL_LOG)$(RESET)"; \
		exit 1; \
	fi

	cp -f $(PROJECT_HWH) $(OUTPUT_HWH)
	$(POST_IMPL_CMDS) 2>&1 | tee -a $(VIVADO_IMPL_LOG)

$(PROJECT_BD): 
	@echo -e "$(GREEN)--- Creating Block Diagram ---$(RESET)"
	@$(RM) -rf $(PROJECT_VIVADO_DIR)/myproj
	@set -o pipefail; cd $(PROJECT_VIVADO_DIR) && $(VIVADO_BASE_CMD) -mode batch -source 01_setup_project.tcl 02_create_bd.tcl 03_gen_products.tcl 2>&1 | tee $(VIVADO_BD_LOG) || \
		{ echo -e "$(RED)Error: Block diagram creation failed. Check $(VIVADO_BD_LOG)$(RESET)"; exit 1; }

# --- Prevent accidental file creation ---
.DELETE_ON_ERROR:
