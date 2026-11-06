`timescale 1ns/1ps
module tb_cm_system;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,host_req=0,host_write=0;reg [18:0] host_addr=0;
 reg [31:0] host_wdata=0;reg [3:0] host_be=15;
 wire host_wait,host_error;wire [31:0] host_rdata;wire [383:0] trace;
 sle_board_core dut(.*);
 integer i,j,expected_length,rx_test_length,tx_received,air_ticks=40,target_fine_expect,alg,md,s;
 reg [31:0] d,head,x;reg [29:0] target;
 reg [31:0] oracle[0:8191],slot_oracle[0:1023];
 initial begin $readmemh("aes_sm4_ccm.mem",oracle);$readmemh("cm_slot_nonce.mem",slot_oracle);end
 function [7:0] pattern(input integer n);pattern=(n*37+11)&255;endfunction
 task bus(input bit wr,input [18:0] address,input [31:0] value,input [3:0] ben,output [31:0] result,input bit expected_error=0);
  @(negedge clk);host_addr=address;host_wdata=value;host_be=ben;host_write=wr;host_req=1;
  do begin @(posedge clk);#1;end while(host_wait);
  result=host_rdata;
  if(host_error!==expected_error)$fatal(1,"CM bus %h err=%b expected=%b",address,host_error,expected_error);
  @(negedge clk);host_req=0;@(negedge clk);
 endtask
 `include "board_test_tasks.vh"
 task key_config;
  wr('h830,'h0c0d0e0f);wr('h834,'h08090a0b);wr('h838,'h04050607);wr('h83c,'h00010203);
  wr('h840,'h08070605);wr('h844,'h0c0b0a09);wr('h850,0);wr('h854,0);
 endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;repeat(20)@(negedge clk);
  wr('h40010,1);wr('h2c,'h80);wr(0,1);wr('h110,1);
  bus(1,'h544,0,15,d,1);bus(1,'h600,16,15,d,1);rd('h600,d);if(d!=0)$fatal(1,"reserved CM bits retained");
  // Five grids on the actual scheduler and immutable per-ET CM configuration.
  for(s=0;s<5;s=s+1)begin
   configure(0,17,0,0);
   wr('h600,8|s);wr('h604,target);wr('h608,0);
   mh('h100,(5<<11)|8);
   bus(1,'h600,0,15,d,1);
   event_get(1,0);event_get(6,0);event_get(2,0);mh('h100,0);
   configure(0,17,0,0);wr('h604,target);mw('h104,(1<<16)|target[29:16]);mh('h100,(5<<11)|8);
   event_get(5,0);mh('h100,0);wr('h060,31);
  end
  wr('h600,0);
  // Packet time nonce: known absolute slot, independent library vectors.
  for(alg=0;alg<2;alg=alg+1)for(md=0;md<2;md=md+1)begin
   wr('h110,0);wr('h40,0);wr('h44,0);wr('he0,'h200);wr('h110,1);
   configure(md,17,0,0);key_config();wr('h800,9|((md==0?0:3)<<20)|((alg+1)<<16));
   wr('h600,'h100);wr('h60c,0);
   for(i=0;i<6;i=i+1)wr('h49000+i*4,slot_oracle[alg*512+i]);
   wr('h40040,21);
   target=100;target_fine_expect=0;mw('h100,(100<<16)|(5<<11)|md);mw('h104,0);mh('h100,(5<<11)|8|md);
   event_get(1,0);event_get(md==0?6:7,0);event_get(2,0);
   if(md==0)for(i=0;i<6;i=i+1)begin
    rd('h48000+i*4,d);for(j=0;j<4;j=j+1)if(i*4+j<21&&d[j*8+:8]!==slot_oracle[alg*512+i][j*8+:8])$fatal(1,"slot nonce TX alg=%d byte=%d",alg,i*4+j);
   end
   else begin mr('h380c,d);if(d[4:0]!=31)$fatal(1,"slot nonce RX %h",d);end
   mh('h100,0);wr('h600,0);
  end
  // Standalone software CCM owns the scheduler memory port until result ACK.
  for(alg=0;alg<2;alg=alg+1)begin
   for(i=0;i<8;i=i+1)mw('h5000+i*4,0);
   mw('h5000,(17<<16)|('h10000/2));mw('h5004,(260<<16)|('h11000/2));
   mw('h5008,'h03020100);mw('h500c,'h07060504);mw('h5010,'h0b0a0908);mw('h5014,12);
   for(i=0;i<5;i=i+1)begin x=0;for(j=0;j<4;j=j+1)x[j*8+:8]=pattern(i*4+j);mw('h10000+i*4,x);end
   wr('hb4,'h0c0d0e0f);wr('hb8,'h08090a0b);wr('hbc,'h04050607);wr('hc0,'h00010203);wr('hc4,'h5000/2);
   wr('hb0,1|(alg<<1));
   do rd('hb0,d);while(!d[1]);if(d[2])$fatal(1,"software CCM failed");
   for(i=0;i<6;i=i+1)begin mr('h11000+i*4,d);for(j=0;j<4;j=j+1)if(i*4+j<21&&d[j*8+:8]!==oracle[(alg*8+4)*512+i][j*8+:8])$fatal(1,"software cipher mismatch");end
   mr('h5018,d);if(d[4:0]!=29)$fatal(1,"software result not committed");
  end
  // Soft reset drains the active software DMA before resetting its engine.
  wr('hb0,1);wr(0,3);
  do rd(0,d);while(d[8]);
  rd('hb0,d);if(d!=0)$fatal(1,"software status survived soft reset");
  mr('h5018,d);if(d[4:0]!=29)$fatal(1,"software command was reset before final ACK");
  wr('h540,1);rd('h548,d);if(d!=0)$fatal(1,"diagnostic clear");
  mw('h15000,'h12345678);mr('h15000,d);rd('h548,d);if(d==0)$fatal(1,"diagnostic read count");rd('h54c,d);if(d==0)$fatal(1,"diagnostic write count");
  $display("SLE_TEST_PASS: tb_cm_system");$finish;
 end
 initial begin #200000000;$fatal(1,"CM system timeout");end
endmodule
