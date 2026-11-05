# Reuse the matching core/IP checkpoints; only the board reset tie changes.
set here [file dirname [file normalize [info script]]]
set stage [file dirname $here]
set_param general.maxThreads 4
open_project $stage/project/sle_board.xpr
open_bd_design [get_files board.bd]
if {![llength [get_bd_cells -quiet one]]} {
 create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 one
 set_property CONFIG.CONST_VAL 1 [get_bd_cells one]
}
set pin [get_bd_pins reset20/aux_reset_in]
set net [get_bd_nets -of_objects $pin]
if {[llength $net]} {disconnect_bd_net $net $pin}
connect_bd_net [get_bd_pins one/dout] $pin
validate_bd_design
if {[get_property CONFIG.C_AUX_RESET_HIGH [get_bd_cells reset20]]!=0} {error "Unexpected auxiliary reset polarity"}
save_bd_design
generate_target all [get_files board.bd]
reset_run synth_1
source $here/finish.tcl
