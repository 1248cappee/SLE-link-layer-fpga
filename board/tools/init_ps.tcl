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
stop
if {[targets -filter {name =~ "ARM*#1"}] ne ""} {
 targets -set -filter {name =~ "ARM*#1"}
 stop
 targets -set -filter {name =~ "ARM*#0"}
}
ps7_init
puts SLE_PS_INIT_PASS
} else {
ps7_post_config
puts SLE_PS_CLOCK_INIT_PASS
}
disconnect
