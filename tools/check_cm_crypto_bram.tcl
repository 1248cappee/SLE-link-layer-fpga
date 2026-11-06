# Directed synthesis: the CCM payload store must use physical block RAM.
set stage [file normalize [lindex $argv 0]]
set_param general.maxThreads 2
create_project -in_memory -part xc7z100ffg900-2
set_property include_dirs [list $stage/rtl] [current_fileset]
read_verilog [glob $stage/rtl/*.v]
synth_design -top rw_cm_crypto_engine -part xc7z100ffg900-2
create_clock -name clk20 -period 50 [get_ports clk]
set brams [get_cells -quiet -hier -filter {REF_NAME =~ RAMB*}]
if {[llength $brams]<1} {error "CCM payload store was not mapped to block RAM"}
if {[llength [get_cells -quiet -hier -filter {IS_BLACKBOX == 1}]]} {error "Unresolved CCM implementation"}
if {[llength [get_cells -quiet -hier -filter {REF_NAME =~ LD*}]]} {error "CCM latch inferred"}
report_drc -checks [get_drc_checks {REQP-1839 REQP-1840}] -file $stage/cm_crypto_bram_drc.rpt
set drc_fp [open $stage/cm_crypto_bram_drc.rpt r]
set drc_text [read $drc_fp];close $drc_fp
if {[regexp {REQP-18(39|40)#[0-9]+} $drc_text]} {error "CCM BRAM has asynchronous control registers"}
set fp [open $stage/cm_crypto_bram.json w]
puts $fp "{\"passed\":true,\"part\":\"xc7z100ffg900-2\",\"block_ram_cells\":[llength $brams],\"scope\":\"CCM_PRIVATE_PAYLOAD_BRAM\"}"
close $fp
report_utilization -hierarchical -file $stage/cm_crypto_bram.rpt
write_checkpoint -force $stage/cm_crypto_synth.dcp
puts "SLE_CM_CRYPTO_BRAM_PASS $brams"
