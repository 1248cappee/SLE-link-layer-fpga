open_hw_manager
connect_hw_server -url localhost:3121
set targets [get_hw_targets]
puts "SLE_JTAG_TARGETS $targets"
foreach target $targets {
 open_hw_target $target
 puts "SLE_JTAG_DEVICES [get_hw_devices]"
 close_hw_target $target
}
if {![llength $targets]} {puts SLE_BOARD_NOT_CONNECTED}
disconnect_hw_server
close_hw_manager
