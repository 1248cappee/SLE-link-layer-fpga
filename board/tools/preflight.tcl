open_hw_manager
connect_hw_server -url localhost:3121
set targets [get_hw_targets]
if {[llength $targets]!=1} {error "Expected one physical JTAG target before PS reset: $targets"}
set target [lindex $targets 0]
open_hw_target $target
set devices [get_hw_devices -filter {PART =~ xc7z100*}]
if {[llength $devices]!=1} {error "Expected one xc7z100 before PS initialization"}
puts "SLE_PREFLIGHT_TARGET $target / [lindex $devices 0]"
close_hw_target
disconnect_hw_server
close_hw_manager
