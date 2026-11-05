set part xc7z100ffg900-2
set top rw_ble_top
if {[info exists ::env(SLE_SYNTH_TOP)]} {set top $::env(SLE_SYNTH_TOP)}
set_param general.maxThreads 1
set_property include_dirs [list [pwd]] [current_fileset]
read_verilog [glob *.v]
synth_design -top $top -part $part -mode out_of_context -flatten_hierarchy rebuilt
create_clock -name core_clk -period 50.000 [get_ports clk]
set data_inputs [get_ports -filter {DIRECTION == IN && NAME != clk && NAME != rst_n}]
set_input_delay -clock core_clk 5.000 $data_inputs
set_output_delay -clock core_clk 5.000 [get_ports -filter {DIRECTION == OUT}]
set_false_path -from [get_ports rst_n]
report_utilization -hierarchical -file utilization_synth.rpt
write_checkpoint -force synthesized.dcp
set blackboxes [get_cells -hier -filter {IS_BLACKBOX == 1}]
set latches [get_cells -hier -filter {REF_NAME == LDCE || REF_NAME == LDPE || REF_NAME == LDCP || REF_NAME == LDCPE}]
if {[llength $blackboxes] != 0} {error "Unresolved black boxes: $blackboxes"}
if {[llength $latches] != 0} {error "Inferred latches: $latches"}
opt_design
place_design
phys_opt_design
route_design
report_utilization -file utilization_routed.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file timing_routed.rpt
report_drc -file drc_routed.rpt
write_checkpoint -force routed.dcp
set setup_path [get_timing_paths -delay_type max -max_paths 1]
set hold_path [get_timing_paths -delay_type min -max_paths 1]
set setup_slack [get_property SLACK $setup_path]
set hold_slack [get_property SLACK $hold_path]
set f [open result.json w]
puts $f "{\"part\":\"$part\",\"clock_mhz\":20,\"setup_slack_ns\":$setup_slack,\"hold_slack_ns\":$hold_slack,\"blackboxes\":0,\"latches\":0}"
close $f
if {$setup_slack < 0 || $hold_slack < 0} {error "Routed timing not met"}
puts "SLE_OOC_PASS"
exit
