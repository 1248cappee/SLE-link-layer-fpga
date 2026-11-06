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
proc save_failure_snapshot {artifact_dir name bit_sha256 detail} {
 set fp [open $artifact_dir/failure_$name.txt w]
 puts $fp "scenario=$name\nseed=deterministic-public-vectors-v1\nbit_sha256=$bit_sha256\ndetail=$detail"
 # Independent test/AON status remains accessible if the LL clock is stopped.
 foreach a {0x40008 0x4000c 0x40018 0x4001c 0x40020 0x40024 0x40028 0x4002c 0x40030 0x40060 0x40064 0x40068 0x4006c 0x40078 0x4007c 0x40080 0x4008c 0x508 0x510 0x514 0x518 0x51c 0x524 0x528} {
  if {[catch {rd $a} value]} {puts $fp [format "%05x ERROR %s" $a $value]} else {puts $fp [format "%05x %08x" $a $value]}
 }
 close $fp
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
set pressure_run [string match *pressure.tcl $suite_file]
set results_name [expr {$pressure_run?"board_pressure.json":"board_results.json"}]
set results [open $artifact_dir/$results_name w]
set started [clock format [clock seconds] -gmt 1 -format {%Y-%m-%dT%H:%M:%SZ}]
puts $results "{\"scope\":\"DIGITAL_TESTER_NO_PHY\",\"bit_sha256\":\"$bit_sha256\",\"started_utc\":\"$started\",\"cases\":\["
set first 1
set heartbeat [clock seconds]
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
  if {[string match cm_* $name]} {set trigger_bit 27}
  if {[string match cm_sleep* $name] && $name ne "cm_sleep_unsafe_rejected"} {set trigger_bit 258}
  if {[string match *mode_1 $name]||[string match secure*mode_1 $name]||[string match mic_failure* $name]||$name eq "crc_error"||$name eq "duplicate"} {set trigger_bit 9}
  if {[string match foundation* $name]||$name eq "register_time_irq"} {set trigger_bit 27}
  if {[string match cancel* $name]||$name eq "commit_499"||$name eq "null_cs"||$name eq "no_buffer"||$name eq "capacity_260"||$name eq "illegal_2048"} {set trigger_bit 78}
  set trigger [string repeat X 384]
  set bit_index [expr {383-$trigger_bit}]
  set trigger [string replace $trigger $bit_index $bit_index 1]
  set_property TRIGGER_COMPARE_VALUE "eq384'b$trigger" $probe
  run_hw_ila $ila
  wr 0x40014 1
  set deadline [expr {[clock milliseconds]+($pressure_run?1815000:15000)}]
  while {1} {
   set status [rd 0x40008]
   if {$pressure_run} {
    after 100
    if {[clock seconds]-$heartbeat>=30} {set heartbeat [clock seconds];puts "SLE_PRESSURE_RUNNING cycles_hi=[rd 0x4007c] cycles_lo=[rd 0x40078] frames=[rd 0x40068] errors=[rd 0x40060]"}
   }
   if {!($status&1)} {break}
   if {[clock milliseconds]>$deadline} {wr 0x40014 2;error "Host timeout waiting for sequence"}
  }
  if {!($status&2)||($status&4)} {error [format "Sequence failure pc_reason=%08x actual=%08x expected=%08x" [rd 0x40018] [rd 0x4001c] [rd 0x40020]]}
  if {$pressure_run} {
   set cycles [expr {([rd 0x4007c]<<32)|[rd 0x40078]}]
   if {$cycles<36000000000} {error "Pressure hardware duration shorter than 30 minutes"}
  }
  foreach item $checks {
   lassign $item a v m
   if {$a==0xffffff00} {audit_competition $m $v $artifact_dir $name;continue}
   set got [rd $a];if {(($got^$v)&$m)!=0} {error [format "Postcheck addr=%05x got=%08x expected=%08x mask=%08x" $a $got $v $m]}
  }
 } detail]} {set ok 0}
 if {[catch {
  # Vivado's wait_on_hw_ila timeout is in minutes, not seconds. Bound the
  # capture in wall-clock milliseconds so an incorrect trigger cannot hang
  # the acceptance client for several minutes.
  set capture_deadline [expr {[clock milliseconds]+5000}]
  while {[get_property STATUS.CORE_STATUS $ila] ne "FULL"} {
   if {[clock milliseconds]>=$capture_deadline} {error "ILA did not fill within 5 seconds; status=[get_property STATUS.CORE_STATUS $ila]"}
   after 10
  }
  set capture [upload_hw_ila_data $ila]
  write_hw_ila_data -csv_file -force $artifact_dir/ila_$name.csv $capture
 } capture_error]} {
  set ok 0;append detail " ILA capture failed: $capture_error"
 }
 if {!$ok} {save_failure_snapshot $artifact_dir $name $bit_sha256 $detail}
 if {!$first} {puts $results ,};set first 0
 set escaped [string map [list "\\" "\\\\" "\"" "\\\"" "\n" "\\n" "\r" ""] $detail]
 puts -nonewline $results "{\"name\":\"$name\",\"passed\":[expr {$ok?"true":"false"}],\"detail\":\"$escaped\",\"sequence_cycles\":[expr {([rd 0x4007c]<<32)|[rd 0x40078]}]}"
 flush $results
 if {!$ok} {puts $results "\]\}";close $results;error "SLE_BOARD_CASE_FAIL $name: $detail"}
 puts "SLE_BOARD_CASE_PASS $name"
}
puts $results "\],\"elapsed_wall_seconds\":[expr {[clock seconds]-[clock scan $started -gmt 1 -format {%Y-%m-%dT%H:%M:%SZ}]}]\}";close $results
puts SLE_DIGITAL_BOARD_SUITE_PASS
close_hw_target
disconnect_hw_server
close_hw_manager
