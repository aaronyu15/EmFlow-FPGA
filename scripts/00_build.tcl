# filename: build.tcl


proc print_green {text} {
    set green "\033\[32m"
    set reset "\033\[0m"
    puts "${green}${text}${reset}"
}

set BUILD_TIME [ clock format [ clock seconds ] ]

#######################################################################################
# User Settings 
#######################################################################################

# global settings
set PROJECT_DIR [file normalize env(PROJECT_DIR)] 

set PROJECT_RTL_DIR             $env(PROJECT_RTL_DIR)
set PROJECT_VERIF_DIR           $env(PROJECT_VERIF_DIR)
set PROJECT_SCRIPT_DIR          $env(PROJECT_SCRIPT_DIR)
set PROJECT_OUTPUT_DIR          $env(PROJECT_OUTPUT_DIR)
set PROJECT_BD                  $env(PROJECT_BD)
set PROJECT_BD_WRAPPER          $env(PROJECT_BD_WRAPPER)

set PROJECT_POST_SYNTH_DIR      $env(PROJECT_POST_SYNTH_DIR)
set PROJECT_POST_OPT_DIR        $env(PROJECT_POST_OPT_DIR)
set PROJECT_POST_PLACE_DIR      $env(PROJECT_POST_PLACE_DIR)
set PROJECT_POST_PHYS_OPT_DIR   $env(PROJECT_POST_PHYS_OPT_DIR)
set PROJECT_POST_ROUTE_DIR      $env(PROJECT_POST_ROUTE_DIR)

set SAVE_OUTPUT_NAME            $env(SAVE_OUTPUT_NAME)

# Default DEVICE_PART 
#set DEVICE_PART xczu1cg-sbva484-1-e
#set BOARD_PART avnet-tria:zuboard_1cg:part0:1.2
set BOARD_PART $env(BOARD_PART)
# Default RTL_TOP_MODULE
set RTL_TOP_MODULE $env(RTL_TOP_MODULE)

# Default RUN_MODE
set RUN_MODE 3 
set GUI 0
set DIRECTIVE default
set help 0

# Process command-line arguments
set i 0
while {$i < $argc} {
    set arg [lindex $argv $i]
    switch -exact -- $arg {
        "-run_mode" {
            incr i
            if {$i < $argc} {
                set RUN_MODE [lindex $argv $i]
            }  
        }
        "-part" {
            incr i
            if {$i < $argc} {
                set DEVICE_PART [lindex $argv $i]
            }
        }
        "-board" {
            incr i
            if {$i < $argc} {
                set BOARD_PART [lindex $argv $i]
            }
        }
        "-top" {
            incr i
            if {$i < $argc} {
                set RTL_TOP_MODULE [lindex $argv $i]
            }
        }
        "-gui" {
            incr i
            if {$i < $argc} {
                set GUI [lindex $argv $i]
            }
        }
        "-directives" {
            incr i
            if {$i < $argc} {
                set DIRECTIVE [lindex $argv $i]
            }
        }
        "-help" - "-h" {
            set help 1
        }
        default {
            puts "Warning: Unknown option '$arg'. Ignoring."
        }
    }
    incr i
}

# Handle help message
if {$help} {
    puts "Usage: $argv0 [options]"
    puts "  -input_file <path> : Specify the input data file (mandatory)"
    puts "  -output_dir <path> : Specify the output directory (default: .) "
    puts "  -verbose           : Enable verbose output"
    puts "  -help / -h         : Display this help message"
    exit 0
}


set OPT_DESIGN_ARGS {}
set PLACE_DESIGN_ARGS {}
set PHYS_OPT_DESIGN_ARGS {}
set ROUTE_DESIGN_ARGS {}

switch $DIRECTIVE {
    "default" {
        lappend OPT_DESIGN_ARGS -directive Default
        lappend PLACE_DESIGN_ARGS -directive Default
        lappend PHYS_OPT_DESIGN_ARGS -directive Default
        lappend ROUTE_DESIGN_ARGS -directive Default
    }
    "fast" {
        lappend OPT_DESIGN_ARGS -directive RuntimeOptimized
        lappend PLACE_DESIGN_ARGS -directive RuntimeOptimized
        lappend PHYS_OPT_DESIGN_ARGS -directive RuntimeOptimized
        lappend ROUTE_DESIGN_ARGS -directive RuntimeOptimized
    }
    "aggressive_explore" {
        set DIRECTIVE "AggressiveExplore"
    }
    default {
        puts "Warning: Unknown directive '$DIRECTIVE'. Using 'Default'."
        set DIRECTIVE "Default"
    }
}


# synthesis related settings
set SYNTH_ARGS {}
#append SYNTH_ARGS -flatten_hierarchy rebuilt
#append SYNTH_ARGS -gated_clock_conversion off
#append SYNTH_ARGS -bufg { 12 }
#append SYNTH_ARGS -fanout_limit {10000}
lappend SYNTH_ARGS -directive default
#append SYNTH_ARGS -fsm_extraction  auto
#append SYNTH_ARGS -keep_equivalent_registers
#append SYNTH_ARGS -resource_sharing auto
#append SYNTH_ARGS -control_set_opt_threshold auto
#append SYNTH_ARGS -no_lc
#append SYNTH_ARGS -shreg_min_size {3}
#append SYNTH_ARGS -shreg_min_size {5}
#append SYNTH_ARGS -max_bram {-1}
#append SYNTH_ARGS -max_dsp {-1}
#append SYNTH_ARGS -cascade_dsp auto
#append SYNTH_ARGS -verbose
#lappend SYNTH_ARGS -verilog_define USE_2X_CLK

set OPT_DESIGN_ARGS {}
set PLACE_DESIGN_ARGS {}
set PHYS_OPT_DESIGN_ARGS {}
set ROUTE_DESIGN_ARGS {}

#lappend OPT_DESIGN_ARGS -directive Default
#lappend PLACE_DESIGN_ARGS -directive ExtraTimingOpt
#lappend PHYS_OPT_DESIGN_ARGS -directive Explore
#lappend ROUTE_DESIGN_ARGS -directive NoTimingRelaxation

# set_part to "create a project"
if {$RUN_MODE != "hw_debug" && $RUN_MODE != "impl_gui" && $RUN_MODE != "synth_gui"} {
    set_part $DEVICE_PART
    set_property target_language Verilog [current_project]
    set_property board_part $BOARD_PART [current_project]
    set_property default_lib work [current_project]
    set_property -name "board_connections" -value "som240_1_connector xilinx.com:kv260_carrier:som240_1_connector:1.3" -objects [current_project]
    set_property -name "platform.board_id" -value "kv260_som_som240_1_connector_kv260_carrier_som240_1_connector" -objects [current_project]
}

#######################################################################################
# Build Design
#######################################################################################

#The default number of maximum simultaneous threads is based on the OS. For Windows systems, the limit is 2; for Linux systems the default is 8.
set_param general.maxThreads 16

switch $RUN_MODE {
    "elab" {
        read_verilog -sv [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/design_pkg.sv"]
        read_bd $PROJECT_BD

        read_verilog -sv [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/*.sv"]
        read_verilog -sv [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/datapath/*.sv"]
        read_verilog -sv [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/mem/*.sv"]

        read_verilog [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/*.v"]
        read_mem [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/mem/files/*.mem"]
        read_xdc [glob -nocomplain "$env(PROJECT_RTL_DIR)/xdc/*.xdc"]

        synth_design -rtl -top $RTL_TOP_MODULE -part $DEVICE_PART {*}$SYNTH_ARGS 
        start_gui
    
    }
    "synth" {
        # read all design files and constraints
        #set FILE_ID [open $RTL_SRC r]
        #while {[gets $FILE_ID line] > 0} {
        #    read_verilog -sv $PROJECT_RTL_DIR/$line
        #}
        #close $FILE_ID
        read_verilog -sv [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/design_pkg.sv"]
        read_bd $PROJECT_BD

        read_verilog -sv [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/*.sv"]
        read_verilog -sv [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/datapath/*.sv"]
        read_verilog -sv [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/mem/*.sv"]

        read_verilog [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/*.v"]
        read_mem [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/mem/files/*.mem"]
        read_xdc [glob -nocomplain "$env(PROJECT_RTL_DIR)/xdc/*.xdc"]

        # Assuming the block design instantiates my RTL module, it should have everything it needs

        # Synthesize Design
        synth_design -top $RTL_TOP_MODULE -part $DEVICE_PART {*}$SYNTH_ARGS 
        write_checkpoint     -force $PROJECT_POST_SYNTH_DIR/post_synth.dcp
        write_verilog        -force -mode design -cell kv260_flow_wrapper_0_0 $PROJECT_POST_SYNTH_DIR/post_synth_block.v
        write_verilog        -force -mode funcsim -cell kv260_flow_wrapper_0_0 $PROJECT_POST_SYNTH_DIR/post_synth_block_funcsim.v
        write_verilog        -force -mode timesim -cell kv260_flow_wrapper_0_0 -sdf_anno true -sdf_file  $PROJECT_POST_SYNTH_DIR/post_synth_block.sdf $PROJECT_POST_SYNTH_DIR/post_synth_block_timesim.v
        write_sdf            -force -cell kv260_flow_wrapper_0_0 $PROJECT_POST_SYNTH_DIR/post_synth_block.sdf
        write_xdc            -no_fixed_only -force $PROJECT_POST_SYNTH_DIR/post_synth.xdc

        report_utilization    -file $PROJECT_POST_SYNTH_DIR/post_synth_util.rpt
        report_drc            -file $PROJECT_POST_SYNTH_DIR/post_synth_drc.rpt
        report_methodology    -file $PROJECT_POST_SYNTH_DIR/post_synth_methodology.rpt
        report_qor_suggestions -file $PROJECT_POST_SYNTH_DIR/post_synth_qor_suggestions.rpt
        report_timing_summary     -file $PROJECT_POST_SYNTH_DIR/post_synth_time_summary.rpt
        report_ram_utilization  -include_lutram     -file $PROJECT_POST_SYNTH_DIR/post_synth_ram_util.rpt
        report_environment      -file $PROJECT_POST_SYNTH_DIR/post_synth_environment.rpt
    }
    "impl" {
        open_checkpoint $PROJECT_POST_SYNTH_DIR/post_synth.dcp

        # Opt Design 
        print_green "-------------------- Starting opt_design --------------------"
        opt_design {*}$OPT_DESIGN_ARGS
        report_timing_summary -file $PROJECT_POST_OPT_DIR/post_opt_time_summary.rpt
        report_utilization    -file $PROJECT_POST_OPT_DIR/post_opt_util.rpt
        report_drc            -file $PROJECT_POST_OPT_DIR/post_opt_drc.rpt
        write_checkpoint     -force $PROJECT_POST_OPT_DIR/post_opt.dcp

        # Power Opt Design (Doing it pre-place can maximize power savings but affect timing)
        #print_green "-------------------- Starting power_opt_design --------------------"
        # power_opt_design -directive Explore

        # Place Design
        print_green "-------------------- Starting place_design --------------------"
        place_design {*}$PLACE_DESIGN_ARGS 
        report_timing_summary -file $PROJECT_POST_PLACE_DIR/post_place_time.rpt
        report_utilization    -file $PROJECT_POST_PLACE_DIR/post_place_util.rpt
        write_checkpoint     -force $PROJECT_POST_PLACE_DIR/post_place.dcp

        # Post Place Power Opt Design (Doing it post-place can preserve timing but may not save as much power)
        #print_green "-------------------- Starting post-place power_opt_design --------------------"
        # power_opt_design -directive Explore

        # Post Place Phys Opt
        print_green "-------------------- Starting phys_opt_design --------------------"
        phys_opt_design {*}$PHYS_OPT_DESIGN_ARGS
        report_timing_summary -file $PROJECT_POST_PHYS_OPT_DIR/post_place_physopt1_time.rpt
        report_utilization    -file $PROJECT_POST_PHYS_OPT_DIR/post_place_physopt1_util.rpt
        report_phys_opt       -file $PROJECT_POST_PHYS_OPT_DIR/post_place_physopt1_status.rpt
        write_checkpoint     -force $PROJECT_POST_PHYS_OPT_DIR/post_place_physopt1.dcp

        # Route Design
        print_green "-------------------- Starting route_design --------------------"
        route_design {*}$ROUTE_DESIGN_ARGS

        report_methodology                          -file $PROJECT_POST_ROUTE_DIR/post_route_methodology.rpt
        report_timing_summary                       -file $PROJECT_POST_ROUTE_DIR/post_route_timing_summary.rpt
        report_timing                               -file $PROJECT_POST_ROUTE_DIR/post_route_timing.rpt
        report_utilization -hierarchical            -file $PROJECT_POST_ROUTE_DIR/post_route_util.rpt
        report_route_status                         -file $PROJECT_POST_ROUTE_DIR/post_route_status.rpt
        report_design_analysis -qor_summary         -file $PROJECT_POST_ROUTE_DIR/post_route_design_analysis.rpt
        report_drc                                  -file $PROJECT_POST_ROUTE_DIR/post_route_drc.rpt
        report_high_fanout_nets -timing -load_types -file $PROJECT_POST_ROUTE_DIR/post_route_methodology.rpt 
        report_power                                -file $PROJECT_POST_ROUTE_DIR/post_route_power.rpt
        report_power_opt                            -file $PROJECT_POST_ROUTE_DIR/post_route_power_opt.rpt
        report_ram_utilization  -include_lutram     -file $PROJECT_POST_ROUTE_DIR/post_route_ram_util.rpt

        # Post Route Phys Opt
        #print_green "-------------------- Starting post-route phys_opt_design --------------------"
        #phys_opt_design -directive AggressiveExplore
        #report_timing_summary -file $PROJECT_POST_PHYS_OPT_DIR/post_place_physopt2_time.rpt
        #report_utilization    -file $PROJECT_POST_PHYS_OPT_DIR/post_place_physopt2_util.rpt
        #write_checkpoint     -force $PROJECT_POST_PHYS_OPT_DIR/post_place_physopt2.dcp

        print_green "-------------------- Finished Implementation. Writing output files --------------------"
        write_checkpoint                -force $PROJECT_POST_ROUTE_DIR/post_route.dcp
        write_verilog            -force -mode design $PROJECT_OUTPUT_DIR/${SAVE_OUTPUT_NAME}_netlist.v
        write_verilog            -mode design -cell kv260_flow_wrapper_0_0 -force $PROJECT_OUTPUT_DIR/${SAVE_OUTPUT_NAME}_block.v
        write_verilog            -mode funcsim -cell kv260_flow_wrapper_0_0 -force $PROJECT_OUTPUT_DIR/${SAVE_OUTPUT_NAME}_block_netlist_funcsim.v
        write_verilog            -mode timesim -cell kv260_flow_wrapper_0_0 -sdf_anno true -sdf_file $PROJECT_OUTPUT_DIR/${SAVE_OUTPUT_NAME}_block.sdf -force $PROJECT_OUTPUT_DIR/${SAVE_OUTPUT_NAME}_block_netlist_timesim.v
        write_sdf            -force -cell kv260_flow_wrapper_0_0 $PROJECT_OUTPUT_DIR/${SAVE_OUTPUT_NAME}_block.sdf
        write_xdc -no_fixed_only -force $PROJECT_OUTPUT_DIR/${SAVE_OUTPUT_NAME}.xdc
        write_bitstream -logic_location_file -bin_file -force $PROJECT_OUTPUT_DIR/${SAVE_OUTPUT_NAME}.bit 
        write_hw_platform -fixed -force -include_bit -file $PROJECT_OUTPUT_DIR/${SAVE_OUTPUT_NAME}.xsa
        write_debug_probes -force $PROJECT_OUTPUT_DIR/${SAVE_OUTPUT_NAME}.ltx
    
    }
    "synth_gui" {
        open_checkpoint $PROJECT_POST_SYNTH_DIR/post_synth.dcp
        start_gui
    }
    "impl_gui" {
        open_checkpoint $PROJECT_POST_ROUTE_DIR/post_route.dcp
        start_gui
    }
    "hw_debug" {
        open_hw_manager
        connect_hw_server -allow_non_jtag
        open_hw_target
    }


}

