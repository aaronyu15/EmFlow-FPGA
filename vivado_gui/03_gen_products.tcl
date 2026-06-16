# filename: gen_products.tcl

set PROJECT_BD $env(PROJECT_BD)
set PROJECT_VERIF_DIR $env(PROJECT_VERIF_DIR)

read_bd $PROJECT_BD

set_property synth_checkpoint_mode None [get_files $PROJECT_BD]

#set_property -name "enable_vhdl_2008" -value "1" -objects [current_project]
#set_property -name "mem.enable_memory_map_generation" -value "1" -objects [current_project]
#set_property -name "simulator_language" -value "Mixed" -objects [current_project]
#set_property -name "target_language" -value "VHDL" -objects [current_project]

generate_target all [get_files $PROJECT_BD]

# moved premade wrapper to rtl/src
#make_wrapper -files [get_files $PROJECT_BD] -top

# This command copies relevent files to the project_1.ip_user_files directory in myproj
# do i need this?
#export_ip_user_files -force -no_script -of_objects [get_files $PROJECT_BD]
export_simulation -export_source_files -simulator xsim -directory $PROJECT_VERIF_DIR -of_objects  [get_files $PROJECT_BD]