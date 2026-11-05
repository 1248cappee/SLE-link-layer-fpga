`timescale 1ns/1ps
module tb_board_reset_ip;
 reg slowest_sync_clk=0;always #25 slowest_sync_clk=~slowest_sync_clk;
 reg ext_reset_in=0,aux_reset_in=1,mb_debug_sys_rst=0,dcm_locked=0;
 wire mb_reset;wire [0:0] bus_struct_reset,peripheral_reset,interconnect_aresetn,peripheral_aresetn;
 // Actual generated Vivado 2020.2 proc_sys_reset wrapper, not a reset stub.
 board_reset20_0 dut(.slowest_sync_clk(slowest_sync_clk),.ext_reset_in(ext_reset_in),
 .aux_reset_in(aux_reset_in),.mb_debug_sys_rst(mb_debug_sys_rst),.dcm_locked(dcm_locked),
 .mb_reset(mb_reset),.bus_struct_reset(bus_struct_reset),.peripheral_reset(peripheral_reset),
 .interconnect_aresetn(interconnect_aresetn),.peripheral_aresetn(peripheral_aresetn));
 task clocks(input integer n);repeat(n)@(negedge slowest_sync_clk);endtask
 task released;
  clocks(200);if(peripheral_aresetn!==1||peripheral_reset!==0)$fatal(1,"board reset did not release");
 endtask
 initial begin
  clocks(10);ext_reset_in=1;dcm_locked=1;released();
  aux_reset_in=0;clocks(30);if(peripheral_aresetn!==0)$fatal(1,"active-low auxiliary reset ignored");
  aux_reset_in=1;released();
  ext_reset_in=0;clocks(30);if(peripheral_aresetn!==0)$fatal(1,"PS reset ignored");
  ext_reset_in=1;released();
  dcm_locked=0;clocks(30);if(peripheral_aresetn!==0)$fatal(1,"MMCM unlock ignored");
  dcm_locked=1;released();
  mb_debug_sys_rst=1;clocks(30);if(peripheral_aresetn!==0)$fatal(1,"debug reset ignored");
  mb_debug_sys_rst=0;released();
  $display("SLE_BOARD_RESET_IP_PASS");$finish;
 end
 initial begin #1000000;$fatal(1,"reset IP timeout");end
endmodule
