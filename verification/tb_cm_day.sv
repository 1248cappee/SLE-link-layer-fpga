`timescale 1ns/1ps
module tb_cm_day;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,load_time=0,snap=0,arm_we=0,restore=0,hold_time=0;
 reg [29:0] load_slot=0,restore_slot=0;
 reg [9:0] load_fine=0,restore_fine=0,restore_day=0;
 reg [31:0] restore_phase=0;reg restore_day_valid=1;
 reg [2:0] arm_data=0;reg [89:0] target_slots=0;reg [29:0] target_fines=0;
 wire [29:0] slot,snap_slot;wire [9:0] fine,snap_fine,day_count;
 wire [31:0] phase;wire [2:0] armed,fired;wire tick_fine,tick_slot,day_valid;
 wire [15:0] time_generation;
 rw_cm_timing_gen clock_dut(.*);
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  if(day_count!=1)$fatal(1,"initial day when MSB=0");
  load_slot=30'h3fffffff;load_fine=249;load_time=1;
  @(negedge clk);load_time=0;
  if(day_count!=0||time_generation!=1)$fatal(1,"day init MSB=1");
  repeat(10)@(negedge clk);
  if(day_count!=1||slot!=0||!day_valid)$fatal(1,"day rollover");
  restore_slot=30'h3fffffff;restore_fine=249;restore_day=1023;restore=1;
  @(negedge clk);restore=0;repeat(10)@(negedge clk);
  if(day_valid||day_count!=1023)$fatal(1,"day exhausted silently wrapped");
  load_slot=0;load_fine=0;load_time=1;
  @(negedge clk);load_time=0;
  if(!day_valid||day_count!=1||time_generation!=2)$fatal(1,"time generation invalidation");
  // Exhaustion must not make old generation-zero contexts valid again.
  load_time=1;
  repeat(65536)@(negedge clk);
  load_time=0;
  if(day_valid||time_generation!=16'hffff)$fatal(1,"generation silently wrapped");
  $display("SLE_TEST_PASS: tb_cm_day");$finish;
 end
endmodule
