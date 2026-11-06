`timescale 1ns/1ps
module tb_time_fifo;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,load_time=0,snap=0,arm_we=0;
 reg [29:0] load_slot=0;reg [9:0] load_fine=0;reg [2:0] arm_data=0;
 reg [89:0] target_slots=0;reg [29:0] target_fines=0;
 wire [29:0] slot,snap_slot;wire [9:0] fine,snap_fine;wire tick_fine,tick_slot;wire [2:0] armed,fired;
 reg restore=0,restore_day_valid=1,hold_time=0;reg [29:0] restore_slot=0;
 reg [9:0] restore_fine=0,restore_day=0;reg [31:0] restore_phase=0;
 wire [31:0] phase;wire [9:0] day_count;wire day_valid;wire [15:0] time_generation;
 rw_cm_timing_gen clock_dut(.*);
 reg push=0,pop=0;reg [71:0] in_event=0;wire [71:0] head;wire [7:0] count;wire full,empty,overflow;
 sle_event_fifo #(.DEPTH(4)) fifo(.*);
 integer i,ticks=0,slot_ticks=0;
 always @(posedge clk) if(rst_n) begin if(tick_fine)ticks=ticks+1;if(tick_slot)slot_ticks=slot_ticks+1;end
 task cycle;@(negedge clk);endtask
 initial begin
  repeat(3)cycle();rst_n=1;
  repeat(101)cycle();if(ticks!=10)$fatal(1,"fine divider %0d",ticks);
  load_slot=30'h3fffffff;load_fine=249;load_time=1;cycle();load_time=0;
  repeat(10)cycle();if(slot!==0||fine!==0)$fatal(1,"30-bit carry failed %h %d",slot,fine);
  snap=1;cycle();snap=0;repeat(20)cycle();if(snap_slot!==0||snap_fine!==0)$fatal(1,"snapshot moved");
  target_slots={30'd0,30'd0,30'd0};target_fines={10'd1,10'd0,10'd0};arm_data=7;arm_we=1;cycle();arm_we=0;
  cycle();#1;if(fired!==7||armed!==0)$fatal(1,"expired timers did not fire once");
  cycle();if(fired!==0)$fatal(1,"timer repeated");
  for(i=0;i<4;i=i+1) begin push=1;in_event=i+10;cycle();end
  push=0;if(!full||count!=4||head!=10)$fatal(1,"FIFO fill");
  in_event=99;push=1;pop=1;cycle();push=0;pop=0;if(count!=4||head!=11||overflow)$fatal(1,"simultaneous full pop/push");
  repeat(5)cycle();if(head!=11)$fatal(1,"head not stable");
  push=1;cycle();push=0;if(!overflow||head!=11)$fatal(1,"overflow changed head");
  $display("SLE_TEST_PASS: tb_time_fifo");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
