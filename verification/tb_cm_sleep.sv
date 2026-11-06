`timescale 1ns/1ps
module tb_cm_sleep;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,host_req=0,host_write=0;reg [18:0] host_addr=0;
 reg [31:0] host_wdata=0;reg [3:0] host_be=15;
 wire host_wait,host_error;wire [31:0] host_rdata;wire [383:0] trace;
 sle_board_core dut(.*);
 reg [31:0] d,q;integer clocks=0,stopped_clocks,t0,t1;
 longint a,b,phase_a,phase_b;
 always @(posedge dut.ll_clk)clocks=clocks+1;
 integer aon_cycles=0;
 always @(posedge clk)aon_cycles=aon_cycles+1;
 task bus(input bit wr,input [18:0] address,input [31:0] value,input bit bad=0);
  @(negedge clk);host_req=1;host_write=wr;host_addr=address;host_wdata=value;
  do begin @(posedge clk);#1;end while(host_wait);
  d=host_rdata;
  if(host_error!==bad)$fatal(1,"sleep bus %h error=%b expected=%b state=%h",address,host_error,bad,dut.debug_sleep_state);
  @(negedge clk);host_req=0;@(negedge clk);
 endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;repeat(20)@(negedge clk);
  bus(1,'h578,1);
  bus(1,'h25000,'h12345678);
  // Real-time continuity is checked against the continuously running AON clock.
  a=dut.debug_slot*250+dut.debug_fine;t0=aon_cycles;
  phase_a=a*10+dut.link_layer.time_phase;
  bus(1,'h034,2000);bus(1,'h030,3);
  wait(dut.debug_sleep_state==3);repeat(3)@(negedge clk);
  stopped_clocks=clocks;repeat(30)@(negedge clk);
  if(clocks!=stopped_clocks)$fatal(1,"main clock did not stop");
  bus(0,'h25000,0,1);bus(0,'h004,0,1);
  bus(0,'h508,0);if(d[3:0]!=3)$fatal(1,"AON status inaccessible");
  wait(dut.debug_sleep_state==0);repeat(3)@(negedge clk);
  b=dut.debug_slot*250+dut.debug_fine;t1=aon_cycles;
  phase_b=b*10+dut.link_layer.time_phase;
  if(phase_b-phase_a!=t1-t0)$fatal(1,"sleep phase lost clocks: actual=%d expected=%d",phase_b-phase_a,t1-t0);
  if((b-a)<((t1-t0)/10)-1 || (b-a)>((t1-t0)/10)+1)
   $fatal(1,"sleep time lost: fine=%d aon=%d",b-a,(t1-t0)/10);
  bus(0,'h25000,0);if(d!='h12345678)$fatal(1,"BRAM retention");
  bus(0,'h574,0);if(!d[0]||!dut.irq)$fatal(1,"wake interrupt missing");
  bus(1,'h574,1);if(dut.irq)$fatal(1,"wake W1C failed");
  bus(0,'h510,0);if(d!=1)$fatal(1,"sleep count");
  bus(0,'h514,0);if(d!=1)$fatal(1,"wake count");
  bus(0,'h51c,0);if(d>63)$fatal(1,"LP quantization correction unbounded %d",d);
  // Software wake is accepted while the LL bus target is stopped.
  bus(1,'h034,20000);bus(1,'h030,3);wait(dut.debug_sleep_state==3);
  bus(1,'h030,4);wait(dut.debug_sleep_state==0);
  bus(0,'h038,0);if(d[11:4]!=8)$fatal(1,"wrong software wake cause");
  // Invalid entry does not stop the clock or touch RAM.
  bus(1,'h034,500);bus(1,'h030,3,1);
  if(dut.debug_sleep_state!=0)$fatal(1,"invalid sleep accepted");
  // Wake before an armed timer and deliver exactly one interrupt.
  bus(1,'h0e8,dut.debug_slot+10);bus(1,'h0ec,0);bus(1,'h0e0,1);
  bus(1,'h034,10000);bus(1,'h030,3);wait(dut.debug_sleep_state==0);
  wait(dut.link_layer.timer_fire[0]);repeat(5)@(negedge clk);
  bus(0,'h010,0);if(!d[1])$fatal(1,"timer lost across sleep");
  bus(1,'h014,2);bus(0,'h010,0);if(d[1])$fatal(1,"timer repeated");
  // A hard reset must reopen the real clock gate and discard the sleep
  // handshake, without clearing BRAM or delivering an old bus completion.
  bus(1,'h034,20000);bus(1,'h030,3);wait(dut.debug_sleep_state==3);
  repeat(4)@(negedge clk);stopped_clocks=clocks;
  repeat(20)@(negedge clk);if(clocks!=stopped_clocks)$fatal(1,"reset fixture did not gate");
  rst_n=0;repeat(5)@(negedge clk);rst_n=1;repeat(25)@(negedge clk);
  if(dut.debug_sleep_state!=0||!dut.ll_clock_enable||clocks==stopped_clocks)$fatal(1,"hard reset did not reopen clock");
  bus(0,'h510,0);if(d!=0)$fatal(1,"old sleep count survived hard reset");
  bus(0,'h514,0);if(d!=0)$fatal(1,"old wake count survived hard reset");
  bus(0,'h25000,0);if(d!='h12345678)$fatal(1,"hard reset destroyed BRAM");
  $display("SLE_TEST_PASS: tb_cm_sleep");$finish;
 end
 initial begin #30000000;$fatal(1,"sleep timeout state=%h",dut.debug_sleep_state);end
endmodule
