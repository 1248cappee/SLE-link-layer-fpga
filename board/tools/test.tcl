set artifact_dir [file normalize [lindex $argv 0]]
set suite_file [file normalize [lindex $argv 1]]
set bit_sha256 [lindex $argv 2]
if {![regexp {^[a-f0-9]{64}$} $bit_sha256]} {error "Expected verified bitstream SHA256 argument"}
open_hw_manager
connect_hw_server -url localhost:3121
if {[llength [get_hw_targets]]!=1} {error "JTAG target is ambiguous"}
set target [lindex [get_hw_targets] 0]
set_property PARAM.FREQUENCY 5000000 $target
open_hw_target $target
set devices [get_hw_devices -filter {PART =~ xc7z100*}]
if {[llength $devices]!=1} {error "xc7z100 target is ambiguous"}
set device [lindex $devices 0]
current_hw_device $device
set_property PROBES.FILE $artifact_dir/sle_board.ltx $device
refresh_hw_device $device
set axes [get_hw_axis -of_objects $device]
if {[llength $axes]!=1} {error "Expected one debug AXI master; verify PS clock/init"}
set axi [lindex $axes 0]
reset_hw_axi $axi
create_hw_axi_txn sle_read $axi -type read -address 40040000 -len 1
create_hw_axi_txn sle_write $axi -type write -address 40040000 -len 1 -data 00000000
proc rd {address} {
 set txn [get_hw_axi_txns sle_read]
 set_property CMD.ADDR [format %08x [expr {0x40000000+$address}]] $txn
 run_hw_axi -quiet $txn
 set data [get_property DATA $txn]
 scan $data %x value
 return [expr {$value&0xffffffff}]
}
proc wr {address value {be 15}} {
 # The JTAG master has full-word strobes. Subword LL accesses run in microcode.
 if {$be!=15} {error "Host subword write requires a microcode instruction"}
 set txn [get_hw_axi_txns sle_write]
 set_property CMD.ADDR [format %08x [expr {0x40000000+$address}]] $txn
 set_property DATA [format %08x [expr {$value&0xffffffff}]] $txn
 run_hw_axi -quiet $txn
}
proc audit_competition {winner expected artifact_dir name} {
 set seen 0;set starts 0;set txs 0;set ends 0
 set fp [open $artifact_dir/events_$name.txt w]
 for {set n 0} {$n<18} {incr n} {
  set h [rd 0x24];puts $fp [format %08x $h]
  set kind [expr {($h>>12)&15}];set idx [expr {($h>>8)&15}]
  if {$kind==1} {incr starts;if {$idx!=$winner} {error "Wrong priority winner"}} elseif {$kind==6} {incr txs;if {$idx!=$winner} {error "Loser transmitted"}} else {
   if {$seen&(1<<$idx)} {error "Duplicate terminal"}
   set seen [expr {$seen|(1<<$idx)}];incr ends
   if {$idx==$winner&&$kind!=2} {error "Winner did not complete"}
   if {$idx!=$winner&&($kind!=3||(($h>>16)&255)!=2)} {error "Wrong conflict reason"}
  }
  wr 0x110 0x201
 }
 close $fp
 if {$starts!=1||$txs!=1||$ends!=16||$seen!=$expected} {error "Competition accounting mismatch"}
}
if {[rd 0x40000]!=0x534c4254} {error "Wrong digital tester build ID"}
set ilas [get_hw_ilas -of_objects $device]
if {[llength $ilas]!=1} {error "Expected one ILA"}
set ila [lindex $ilas 0]
set_property CONTROL.TRIGGER_POSITION 1024 $ila
# Capture condition is read-only in this 2020.2 ILA configuration (ALWAYS).
set probes [get_hw_probes -of_objects $ila]
if {[llength $probes]!=1} {error "Unexpected ILA probe layout"}
set probe [lindex $probes 0]
source $suite_file
set results [open $artifact_dir/board_results.json w]
set started [clock format [clock seconds] -gmt 1 -format {%Y-%m-%dT%H:%M:%SZ}]
puts $results "{\"scope\":\"DIGITAL_TESTER_NO_PHY\",\"bit_sha256\":\"$bit_sha256\",\"started_utc\":\"$started\",\"cases\":\["
set first 1
foreach scenario $sle_cases {
 lassign $scenario name setup code checks
 set ok 1;set detail ""
 puts "SLE_BOARD_CASE_START $name"
 if {[catch {
  foreach item $setup {lassign $item a v b;wr $a $v $b}
  set pos 0;foreach word $code {wr [expr {0x44000+$pos*4}] $word;incr pos}
  # trace[27]=sequence busy; [78]=FIFO count bit0; [17]=TX launch; [9]=RX IRQ.
  # Arm before START, so host/JTAG latency cannot miss the actual event.
  set trigger_bit 17
  if {[string match *mode_1 $name]||[string match secure*mode_1 $name]||[string match mic_failure* $name]||$name eq "crc_error"||$name eq "duplicate"} {set trigger_bit 9}
  if {[string match foundation* $name]||$name eq "register_time_irq"} {set trigger_bit 27}
  if {[string match cancel* $name]||$name eq "commit_499"||$name eq "null_cs"||$name eq "no_buffer"||$name eq "capacity_260"||$name eq "illegal_2048"} {set trigger_bit 78}
  set trigger [string repeat X 256]
  set bit_index [expr {255-$trigger_bit}]
  set trigger [string replace $trigger $bit_index $bit_index 1]
  set_property TRIGGER_COMPARE_VALUE "eq256'b$trigger" $probe
  run_hw_ila $ila
  wr 0x40014 1
  set deadline [expr {[clock milliseconds]+15000}]
  while {1} {
   set status [rd 0x40008]
   if {!($status&1)} {break}
   if {[clock milliseconds]>$deadline} {wr 0x40014 2;error "Host timeout waiting for sequence"}
  }
  if {!($status&2)||($status&4)} {error [format "Sequence failure pc_reason=%08x actual=%08x expected=%08x" [rd 0x40018] [rd 0x4001c] [rd 0x40020]]}
  foreach item $checks {
   lassign $item a v m
   if {$a==0xffffff00} {audit_competition $m $v $artifact_dir $name;continue}
   set got [rd $a];if {(($got^$v)&$m)!=0} {error [format "Postcheck addr=%05x got=%08x expected=%08x mask=%08x" $a $got $v $m]}
  }
 } detail]} {set ok 0}
 if {[catch {
  wait_on_hw_ila -timeout 5 $ila
  set capture [upload_hw_ila_data $ila]
  write_hw_ila_data -csv_file -force $artifact_dir/ila_$name.csv $capture
 } capture_error]} {
  set ok 0;append detail " ILA capture failed: $capture_error"
 }
 if {!$first} {puts $results ,};set first 0
 set escaped [string map [list "\\" "\\\\" "\"" "\\\"" "\n" "\\n" "\r" ""] $detail]
 puts -nonewline $results "{\"name\":\"$name\",\"passed\":[expr {$ok?"true":"false"}],\"detail\":\"$escaped\"}"
 flush $results
 if {!$ok} {puts $results "\]\}";close $results;error "SLE_BOARD_CASE_FAIL $name: $detail"}
 puts "SLE_BOARD_CASE_PASS $name"
}
puts $results "\]\}";close $results
puts SLE_DIGITAL_BOARD_SUITE_PASS
close_hw_target
disconnect_hw_server
close_hw_manager
