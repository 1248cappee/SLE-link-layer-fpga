launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "synthesis failed"}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "implementation failed"}
open_run impl_1
file mkdir $stage/results
report_utilization -file $stage/results/utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file $stage/results/timing.rpt
report_drc -file $stage/results/drc.rpt
report_cdc -file $stage/results/cdc.rpt
report_methodology -file $stage/results/methodology.rpt
check_timing -verbose -file $stage/results/check_timing.rpt
report_bus_skew -file $stage/results/bus_skew.rpt
set setup [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set hold [get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]
if {$setup<0 || $hold<0} {error "Timing failed setup=$setup hold=$hold"}
if {[llength [get_cells -hier -filter {IS_BLACKBOX == 1}]]} {error "Black boxes remain"}
if {[llength [get_cells -hier -filter {REF_NAME =~ LD*}]]} {error "Latches remain"}
set drc_file [open $stage/results/drc.rpt r]
set drc_text [read $drc_file];close $drc_file
if {[regexp {REQP-18(39|40)#[0-9]+} $drc_text]} {error "Asynchronous BRAM controls remain"}
write_debug_probes -force $stage/results/sle_board.ltx
file copy -force $stage/project/sle_board.runs/impl_1/board_wrapper.bit $stage/results/sle_board.bit
write_hw_platform -fixed -include_bit -force -file $stage/results/sle_board.xsa
set fp [open $stage/results/implementation.json w]
puts $fp "{\"part\":\"xc7z100ffg900-2\",\"clock_hz\":20000000,\"setup_slack_ns\":$setup,\"hold_slack_ns\":$hold,\"scope\":\"DIGITAL_TESTER_NO_PHY\"}"
close $fp
puts SLE_BOARD_IMPLEMENTATION_PASS
