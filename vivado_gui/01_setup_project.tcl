create_project project_1 myproj -part $env(DEVICE_PART)

puts $env(PROJECT_RTL_DIR)
puts [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/*.sv"]

add_files -fileset sources_1 [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/*.sv"]
add_files -fileset sources_1 [glob -nocomplain "$env(PROJECT_RTL_DIR)/src/*.v"]
add_files -fileset constrs_1 [glob -nocomplain "$env(PROJECT_RTL_DIR)/xdc/*.xdc"]

set_property -name "board_part" -value $env(BOARD_PART) -objects [current_project]
if { $env(BOARD_PART) == "xilinx.com:kv260_som:part0:1.4"} {
set_property -name "board_connections" -value "som240_1_connector xilinx.com:kv260_carrier:som240_1_connector:1.3" -objects [current_project]
set_property -name "platform.board_id" -value "kv260_som_som240_1_connector_kv260_carrier_som240_1_connector" -objects [current_project]
}


# Set IP repository paths
set obj [get_filesets sources_1]
if { $obj != {} } {
   set origin_dir [file dirname [file normalize [info script]]]/../ip
   set_property "ip_repo_paths" "[file normalize $origin_dir]" $obj
   puts $origin_dir

   # Rebuild user ip_repo's index before adding any source files
   update_ip_catalog -rebuild
}
