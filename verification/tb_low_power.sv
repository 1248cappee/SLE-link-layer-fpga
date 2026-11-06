`timescale 1ns/1ps
module tb_low_power;
 reg low_power_clk=0;always #15258.7890625 low_power_clk=~low_power_clk;
 reg low_power_nrst=0,load=0,enable=1;reg [29:0] load_slot=0;reg [9:0] load_fine=0;
 wire [29:0] slot;wire [9:0] fine;
 rw_ble_top_tglp_ext dut(.*);
 initial begin
  repeat(4)@(negedge low_power_clk);low_power_nrst=1;
  repeat(32768)@(negedge low_power_clk);if(slot!==8000||fine!==0)$fatal(1,"LP fractional drift slot=%d fine=%d",slot,fine);
  $display("SLE_TEST_PASS: tb_low_power");$finish;
 end
endmodule
