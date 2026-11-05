set artifact_dir [file normalize [lindex $argv 0]]
open_hw_manager
connect_hw_server -url localhost:3121
set targets [get_hw_targets]
if {[llength $targets]!=1} {error "Expected one JTAG target, got: $targets"}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY 5000000 $target
open_hw_target $target
set devices [get_hw_devices -filter {PART =~ xc7z100*}]
if {[llength $devices]!=1} {error "Expected one xc7z100, got: [get_hw_devices]"}
set device [lindex $devices 0]
current_hw_device $device
puts "SLE_PROGRAM_TARGET $target / $device / [get_property PART $device]"
set_property PROGRAM.FILE $artifact_dir/sle_board.bit $device
set_property PROBES.FILE $artifact_dir/sle_board.ltx $device
program_hw_devices $device
puts SLE_VOLATILE_PROGRAM_PASS
close_hw_target
disconnect_hw_server
close_hw_manager
