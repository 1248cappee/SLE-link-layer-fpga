# Read-only post-route check: every debug clock must stay in the AON domain.
set stage [file normalize [lindex $argv 0]]
open_checkpoint $stage/project/sle_board.runs/impl_1/board_wrapper_routed.dcp
set aon [get_nets -quiet board_i/clk20_clk_out1]
if {[llength $aon]!=1} {error "AON clock net not uniquely identified"}
proc clock_driver {net} {
 return [lsort [get_pins -quiet -leaf -of_objects [get_nets -segments $net] -filter {DIRECTION == OUT}]]
}
set expected [clock_driver $aon]
if {[llength $expected]!=1} {error "AON clock driver not unique: $expected"}
set fp [open $stage/results/debug_clocks.rpt w]
puts $fp "AON_DRIVER $expected"
foreach name {dbg_hub/clk board_i/ila/clk board_i/jtag/aclk board_i/test_core/inst/clk} {
 set pin [get_pins -quiet $name]
 if {[llength $pin]!=1} {error "Debug clock pin missing: $name"}
 set actual [clock_driver [get_nets -of_objects $pin]]
 puts $fp "$name DRIVER=$actual"
 if {$actual ne $expected} {error "Debug clock is not AON: $name -> $actual"}
}
set gate [get_cells -quiet board_i/test_core/inst/core/gate/gate_buffer]
if {[llength $gate]!=1} {error "Main clock gate not uniquely identified"}
set ref [get_property REF_NAME $gate]
set transformed [expr {$ref eq "BUFGCTRL" && [get_property XILINX_LEGACY_PRIM $gate] eq "BUFGCE" && [get_property CE_TYPE_CE0 $gate] eq "SYNC"}]
if {$ref ne "BUFGCE" && !$transformed} {error "Main clock must use dedicated BUFGCE or its BUFGCTRL expansion"}
puts $fp "MAIN_GATE $gate $ref BUFGCE_EXPANSION=$transformed"
set sim_device [get_property SIM_DEVICE $gate]
puts $fp "MAIN_GATE_SIM_DEVICE $sim_device"
if {$sim_device ne "7SERIES"} {error "Main clock gate is not configured for 7SERIES: $sim_device"}
puts $fp SLE_DEBUG_CLOCK_CHECK_PASS
close $fp
puts SLE_DEBUG_CLOCK_CHECK_PASS
