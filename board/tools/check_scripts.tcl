set here [file dirname [file normalize [info script]]]
foreach file [glob $here/*.tcl] {
 set fp [open $file r];set script [read $fp];close $fp
 if {![info complete $script]} {error "Incomplete Tcl: $file"}
}
source $here/../cases/suite.tcl
if {[llength $sle_cases]<80} {error "Unexpected scenario count"}
puts SLE_BOARD_TCL_PARSE_PASS
