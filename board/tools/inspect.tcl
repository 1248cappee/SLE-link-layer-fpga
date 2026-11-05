open_hw_manager
connect_hw_server -url localhost:3121
set target [lindex [get_hw_targets] 0]
set_property PARAM.FREQUENCY 5000000 $target
open_hw_target $target
set device [lindex [get_hw_devices -filter {PART =~ xc7z100*}] 0]
current_hw_device $device
set_property PROBES.FILE [file normalize [file dirname [info script]]/../../build/board/sle_board.ltx] $device
refresh_hw_device $device
set axi [lindex [get_hw_axis -of_objects $device] 0]
create_hw_axi_txn inspect_read $axi -type read -address 40040000 -len 1
report_property [get_hw_axi_txns inspect_read]
set ila [lindex [get_hw_ilas -of_objects $device] 0]
report_property $ila
foreach p [get_hw_probes -of_objects $ila] {report_property $p}
close_hw_target
disconnect_hw_server
close_hw_manager
