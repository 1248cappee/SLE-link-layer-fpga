set artifact_dir [file normalize [lindex $argv 0]]
set bit_sha [lindex $argv 1]
open_hw_manager
connect_hw_server -url localhost:3121
if {[llength [get_hw_targets]]!=1} {error "Ambiguous JTAG target"}
open_hw_target [lindex [get_hw_targets] 0]
set devices [get_hw_devices -filter {PART =~ xc7z100*}]
if {[llength $devices]!=1} {error "Ambiguous P101 device"}
set device [lindex $devices 0];current_hw_device $device
set_property PROBES.FILE $artifact_dir/sle_board.ltx $device
refresh_hw_device $device
set axi [lindex [get_hw_axis -of_objects $device] 0]
reset_hw_axi $axi
create_hw_axi_txn stop_read $axi -type read -address 40040000 -len 1
create_hw_axi_txn stop_write $axi -type write -address 40040014 -len 1 -data 00000002
proc rd {a} {
 set t [get_hw_axi_txns stop_read];set_property CMD.ADDR [format %08x [expr {0x40000000+$a}]] $t
 run_hw_axi -quiet $t;scan [get_property DATA $t] %x value;return [expr {$value&0xffffffff}]
}
proc wr {a v} {
 set t [get_hw_axi_txns stop_write];set_property CMD.ADDR [format %08x [expr {0x40000000+$a}]] $t
 set_property DATA [format %08x $v] $t;run_hw_axi -quiet $t
}
set id [rd 0x40000]
if {$id!=0x534c4254} {set id [rd 0x40000]}
if {$id!=0x534c4254} {error "Unexpected tester image"}
wr 0x40014 2
set deadline [expr {[clock milliseconds]+5000}]
while {[rd 0x40008]&1} {if {[clock milliseconds]>$deadline} {error "Sequence abort did not settle"};after 10}
wr 0x030 4
while {[rd 0x508]&15} {if {[clock milliseconds]>$deadline} {error "Main clock did not wake"};after 10}
wr 0x110 0x101
set fp [open $artifact_dir/pressure_stop_events.txt w]
while {1} {
 set head [rd 0x24]
 if {$head&255} {puts $fp [format %08x $head];wr 0x110 0x201;continue}
 set status [rd 0x40008]
 if {!($status&8) && ($status&0xc0)==0xc0} {break}
 if {[clock milliseconds]>$deadline} {error "Link layer did not drain after cancel"}
 after 10
}
close $fp
wr 0x110 0
wr 0x40010 0
set cycles [expr {([rd 0x4007c]<<32)|[rd 0x40078]}]
set errors [rd 0x40060];set mismatch [rd 0x4008c];set frames [rd 0x40068]
set status [rd 0x40008];set reason [rd 0x40018]
set ila [lindex [get_hw_ilas -of_objects $device] 0]
if {[get_property STATUS.CORE_STATUS $ila] eq "FULL"} {
 set capture [upload_hw_ila_data $ila]
 write_hw_ila_data -csv_file -force $artifact_dir/ila_cm_pressure_user_stopped.csv $capture
}
set fp [open $artifact_dir/pressure_stop.json w]
puts $fp "{\"status\":\"USER_STOPPED\",\"bit_sha256\":\"$bit_sha\",\"sequence_cycles\":$cycles,\"model_errors\":$errors,\"first_mismatch\":$mismatch,\"tx_frames\":$frames,\"final_tester_status\":$status,\"pc_reason\":$reason,\"quiescent\":true,\"tester_disabled\":true}"
close $fp
puts "SLE_PRESSURE_SAFE_USER_STOP_PASS cycles=$cycles errors=$errors frames=$frames status=$status"
close_hw_target;disconnect_hw_server;close_hw_manager
