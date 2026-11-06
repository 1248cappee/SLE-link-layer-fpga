set here [file dirname [file normalize [info script]]]
set stage [file dirname $here]
set_param general.maxThreads 4
create_project sle_board $stage/project -part xc7z100ffg900-2 -force
set_property target_language Verilog [current_project]
add_files [concat [glob $stage/rtl/*.v] [glob $stage/rtl/*.vh]]
set_property include_dirs [list $stage/rtl] [current_fileset]
update_compile_order -fileset sources_1
create_bd_design board
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 ps7]
source $here/ps_preset.tcl
set_property -dict $p101_ps_config $ps
set_property -dict [list CONFIG.PCW_USE_M_AXI_GP0 {0} CONFIG.PCW_USE_M_AXI_GP1 {0} CONFIG.PCW_USE_S_AXI_HP0 {0} CONFIG.PCW_USE_S_AXI_HP1 {0} CONFIG.PCW_USE_S_AXI_HP2 {0} CONFIG.PCW_USE_S_AXI_HP3 {0} CONFIG.PCW_EN_CLK1_PORT {0} CONFIG.PCW_EN_CLK2_PORT {0} CONFIG.PCW_EN_CLK3_PORT {0}] $ps
set_property CONFIG.PCW_SPI0_PERIPHERAL_ENABLE 0 $ps
make_bd_intf_pins_external [get_bd_intf_pins ps7/DDR]
make_bd_intf_pins_external [get_bd_intf_pins ps7/FIXED_IO]
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk20
set_property -dict [list CONFIG.PRIM_SOURCE {No_buffer} CONFIG.PRIM_IN_FREQ {100.000} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {20.000} CONFIG.RESET_TYPE {ACTIVE_LOW}] [get_bd_cells clk20]
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 reset20
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 zero
set_property CONFIG.CONST_VAL 0 [get_bd_cells zero]
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 one
set_property CONFIG.CONST_VAL 1 [get_bd_cells one]
create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi:1.2 jtag
set_property -dict [list CONFIG.PROTOCOL {2} CONFIG.M_AXI_ADDR_WIDTH {32} CONFIG.M_AXI_DATA_WIDTH {32}] [get_bd_cells jtag]
create_bd_cell -type module -reference sle_board_axi test_core
create_bd_cell -type ip -vlnv xilinx.com:ip:ila:6.2 ila
set_property -dict [list CONFIG.C_MONITOR_TYPE {Native} CONFIG.C_NUM_OF_PROBES {1} CONFIG.C_PROBE0_WIDTH {384} CONFIG.C_DATA_DEPTH {4096} CONFIG.C_ADV_TRIGGER {true}] [get_bd_cells ila]
connect_bd_net [get_bd_pins ps7/FCLK_CLK0] [get_bd_pins clk20/clk_in1]
connect_bd_net [get_bd_pins ps7/FCLK_RESET0_N] [get_bd_pins clk20/resetn] [get_bd_pins reset20/ext_reset_in]
connect_bd_net [get_bd_pins clk20/locked] [get_bd_pins reset20/dcm_locked]
connect_bd_net [get_bd_pins zero/dout] [get_bd_pins reset20/mb_debug_sys_rst]
connect_bd_net [get_bd_pins one/dout] [get_bd_pins reset20/aux_reset_in]
connect_bd_net [get_bd_pins clk20/clk_out1] [get_bd_pins reset20/slowest_sync_clk] [get_bd_pins jtag/aclk] [get_bd_pins test_core/clk] [get_bd_pins ila/clk]
connect_bd_net [get_bd_pins reset20/peripheral_aresetn] [get_bd_pins jtag/aresetn] [get_bd_pins test_core/rst_n]
connect_bd_intf_net [get_bd_intf_pins jtag/M_AXI] [get_bd_intf_pins test_core/S_AXI]
connect_bd_net [get_bd_pins test_core/trace] [get_bd_pins ila/probe0]
assign_bd_address -offset 0x40000000 -range 0x00080000 [get_bd_addr_segs test_core/S_AXI/reg0]
validate_bd_design
if {[get_property CONFIG.C_AUX_RESET_HIGH [get_bd_cells reset20]]!=0} {error "Unexpected auxiliary reset polarity; inactive tie must be checked"}
save_bd_design
generate_target all [get_files board.bd]
make_wrapper -files [get_files board.bd] -top -import
set_property top board_wrapper [current_fileset]
update_compile_order -fileset sources_1
source $here/finish.tcl
