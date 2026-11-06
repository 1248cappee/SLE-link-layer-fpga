`timescale 1ns/1ps
module tb_board;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,host_req=0,host_write=0;reg [18:0] host_addr=0;
 reg [31:0] host_wdata=0;reg [3:0] host_be=15;
 wire host_wait,host_error;wire [31:0] host_rdata;wire [383:0] trace;
 sle_board_core dut(.*);
 integer i,j,expected_length,rx_test_length,tx_received,air_ticks=40,target_fine_expect,mode_test;
 reg [31:0] d,head,x;reg [29:0] target;
 reg [31:0] oracle[0:8191];integer alg,n,lead_test,actual_lead=-1;
 initial $readmemh("aes_sm4_ccm.mem",oracle);
 always @(posedge clk)if(dut.link_layer.commit)
  actual_lead=(dut.sequence_controller.target_slot-dut.debug_slot)*250+dut.sequence_controller.target_fine-dut.debug_fine;
 function [7:0] pattern(input integer n);pattern=(n*37+11)&255;endfunction
 task bus(input bit wr,input [18:0] address,input [31:0] value,input [3:0] ben,output [31:0] result,input bit expected_error=0);
  @(negedge clk);host_addr=address;host_wdata=value;host_be=ben;host_write=wr;host_req=1;
  do begin @(posedge clk);#1;end while(host_wait);
  result=host_rdata;
  if(host_error!==expected_error)$fatal(1,"board bus error %h actual=%b expected=%b",address,host_error,expected_error);
  @(negedge clk);host_req=0;@(negedge clk);
 endtask
 `include "board_test_tasks.vh"
 initial begin
  repeat(4)@(negedge clk);rst_n=1;repeat(16)@(negedge clk);
  rd('h40000,d);if(d!==32'h534c4254)$fatal(1,"build identity");
  wr('h40010,1);wr('h02c,'h80);wr('h00c,'h3f);wr(0,1);wr('h110,1);
  for(i=0;i<512;i=i+1)begin x=0;for(j=0;j<4;j=j+1)x[j*8+:8]=pattern(i*4+j);wr('h49000+i*4,x);end
  for(mode_test=0;mode_test<4;mode_test=mode_test+1)begin
   configure(mode_test,17,mode_test[0]);
   bus(1,'h40010,0,15,d,1);
   event_get(1,0);
   if(mode_test==0)event_get(6,0);
   if(mode_test==1)event_get(7,0);
   if(mode_test==2)begin event_get(6,0);event_get(7,0);end
   if(mode_test==3)begin event_get(7,0);event_get(6,0);end
   event_get(2,0);
   rd('h40060,d);if(d!=0)$fatal(1,"tester protocol failure %h",d);
   if(mode_test!=0)begin
    mr('h380c,d);if(d[4:0]!=19)$fatal(1,"RX outcome %h",d);
    for(i=0;i<17;i=i+1)begin mr(('h10800+(mode_test[0]?2:0)+i)&~3,d);if(d[((i+(mode_test[0]?2:0))%4)*8+:8]!==pattern(i))$fatal(1,"board RX data");end
   end
   if(mode_test!=1)begin
    for(i=0;i<5;i=i+1)begin rd('h48000+i*4,d);for(j=0;j<4;j=j+1)if(i*4+j<17&&d[j*8+:8]!==pattern(i*4+j))$fatal(1,"captured TX mismatch");end
   end
   mh('h100,0);
  end
  // Real delayed mailbox responses, CRC rejection and mailbox release.
  wr('h40048,17);wr('h40044,0);configure(1,17);event_get(1,0);event_get(7,0);event_get(2,0);
  mr('h380c,d);if(d[4:0]!=1)$fatal(1,"CRC failed delivered");mh('h100,0);
  wr('h40044,1);wr('h40040,2047);configure(1,2047);event_get(1,0);event_get(7,0);event_get(2,0);
  for(i=0;i<2047;i=i+1)begin mr(('h10800+i)&~3,d);if(d[(i%4)*8+:8]!==pattern(i))$fatal(1,"large RX payload %0d",i);end
  mh('h100,0);
  // Security is computed by the LL. The tester only supplies/captures bytes.
  for(alg=0;alg<2;alg=alg+1)begin
   wr('h40040,21);wr('h40044,1);
   for(i=0;i<6;i=i+1)wr('h49000+i*4,oracle[(alg*8+4)*512+i]);
   configure(1,17,0,0);
   wr('h800,9|(3<<20)|((alg+1)<<16));
   wr('h830,'h0c0d0e0f);wr('h834,'h08090a0b);wr('h838,'h04050607);wr('h83c,'h00010203);
   wr('h840,'h08070605);wr('h844,'h0c0b0a09);wr('h848,'h03020100);wr('h84c,4);wr('h850,0);wr('h828,'h03020100);wr('h82c,4);
   target=dut.debug_slot+20;mw('h100,(target[15:0]<<16)|(5<<11)|1);mw('h104,target[29:16]);mh('h100,(5<<11)|9);
   event_get(1,0);event_get(7,0);event_get(2,0);mr('h380c,d);if(d[4:0]!=31)$fatal(1,"board secure outcome");
   for(i=0;i<17;i=i+1)begin mr(('h10800+i)&~3,d);if(d[(i%4)*8+:8]!==pattern(i))$fatal(1,"board decrypt");end
   mh('h100,0);
  end
  wr('h40040,17);
  // Exercise the actual integrated scheduler's commit timestamp at 499/500/501.
  for(lead_test=499;lead_test<=501;lead_test=lead_test+1)begin
   configure(0,17,0,0);
   wr('h44000,7);wr('h44004,'h20100);wr('h44008,20);wr('h4400c,(100<<16)|(5<<11));
   wr('h44010,8);wr('h44014,0);wr('h44018,lead_test);wr('h4401c,0);wr('h44020,0);
   actual_lead=-1;wr('h40014,1);do rd('h40008,d);while(d[0]);
   if(d[2])$fatal(1,"timed publish sequence");
   if(actual_lead!=lead_test)$fatal(1,"commit lead got %0d expected %0d",actual_lead,lead_test);
   do rd('h24,head);while(head[7:0]==0);
   if(lead_test==499)begin if(head[23:12]!='h013)$fatal(1,"late accepted %h",head);wr('h110,'h201);end
   else begin
    if(head[15:12]!=1)$fatal(1,"legal commit rejected %h",head);
    wr('h110,'h201);event_get(6,0);event_get(2,0);
   end
   mh('h100,0);
  end
  // Microcode CHECK, WRITE, POLL, error expectation and exclusivity.
  wr('h44000,'hf02);wr('h44004,4);wr('h44008,'h534c0100);wr('h4400c,'hffffffff);
  wr('h44010,'hf01);wr('h44014,'h25000);wr('h44018,'h12345678);wr('h4401c,0);
  wr('h44020,'hf02);wr('h44024,'h25000);wr('h44028,'h12345678);wr('h4402c,'hffffffff);
  wr('h44030,3);wr('h44034,0);wr('h44038,200);wr('h4403c,0);
  wr('h44040,'h10f02);wr('h44044,'h18000);wr('h44048,0);wr('h4404c,0);
  wr('h44050,0);wr('h40014,1);
  bus(0,4,0,15,d,1);
  do rd('h40008,d);while(d[0]);
  if(!d[1]||d[2])$fatal(1,"microcode failure %h",d);
  // Expected mismatch produces a stable diagnostic rather than false PASS.
  wr('h44008,0);wr('h40014,1);do rd('h40008,d);while(d[0]);
  if(!d[2])$fatal(1,"missing negative-test failure");
  rd('h40018,d);if(d[17:10]!=3)$fatal(1,"failure reason");
  $display("SLE_TEST_PASS: tb_board");$finish;
 end
 initial begin #150000000;$fatal(1,"board timeout");end
endmodule
