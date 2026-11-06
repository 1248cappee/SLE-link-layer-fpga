proc halt_if_running {} {
 if {[catch {stop} message] && ![string match -nocase {*already stopped*} $message]} {error $message}
}
if {[catch {
 set artifact_dir [file normalize [lindex $argv 0]]
 set phase [lindex $argv 1]
 if {$phase ni {init post}} {error "Expected phase init or post"}
 connect -url tcp:127.0.0.1:3121
 set matches [targets -filter {name =~ "ARM*#0"}]
 if {$matches eq ""} {error "ARM core0 not found"}
 targets -set -filter {name =~ "ARM*#0"}
 source $artifact_dir/ps7_init.tcl
 if {$phase eq "init"} {
  rst -system
  after 1000
  halt_if_running
  if {[targets -filter {name =~ "ARM*#1"}] ne ""} {
   targets -set -filter {name =~ "ARM*#1"};halt_if_running
   targets -set -filter {name =~ "ARM*#0"}
  }
  puts "SLE_PS_FCLK_BEFORE_INIT [mrd -value 0xF8000170]"
  ps7_init
 }
 if {$phase eq "post"} {ps7_post_config}
 set fclk [mrd -value 0xF8000170]
 set iopll [mrd -value 0xF8000108]
 puts "SLE_PS_CLOCK_READBACK FCLK0=$fclk IOPLL=$iopll"
 if {($fclk&0x03f03f30)!=0x00200500 || ($iopll&0x0007f000)!=0x0001e000} {error "P101 PS clock configuration readback mismatch"}
 puts [expr {$phase eq "init"?"SLE_PS_INIT_PASS":"SLE_PS_CLOCK_INIT_PASS"}]
 disconnect
} failure]} {
 puts stderr "SLE_PS_INIT_FAIL: $failure"
 exit 1
}
exit 0
