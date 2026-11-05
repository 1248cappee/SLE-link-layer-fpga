`timescale 1ns/1ps
module tb_scheduler;
 `include "system_harness.vh"
 integer terminals,starts,tx_facts,idx,kind;
 reg [15:0] terminal_seen;
 initial begin
  phy_caps=15;hready_in=1;repeat(5)@(negedge clk);rst_n=1;
  wr('h02c,'h80);wr(0,1);wr('h110,1);
  configure(0,17);
  // The first task is already prefetching when successively higher-priority
  // tasks are published. All immutable objects are shared until retirement.
  for(integer e=1;e<16;e=e+1)begin
   wr('h800+e*128,9);wr('h818+e*128,20);wr('h820+e*128,'h3000/2);wr('h824+e*128,'h3800/2);wr('h858+e*128,76);
   mw('h100+e*16,(target[15:0]<<16)|(e<<11));mw('h104+e*16,{16'd0,2'd0,target[29:16]});mw('h108+e*16,'h400/2);mw('h10c+e*16,0);
   mh('h100+e*16,(e<<11)|8);
  end
  terminals=0;starts=0;tx_facts=0;terminal_seen=0;
  while(terminals<16)begin
   do rd('h24,head);while(head[7:0]==0);
   idx=head[11:8];kind=head[15:12];
   if(kind==1)begin
    starts=starts+1;if(idx!=15)$fatal(1,"priority winner %0d",idx);
    rd('h114,d);if(d[29:0]!=target)$fatal(1,"winner start time");
   end else if(kind==6)begin tx_facts=tx_facts+1;if(idx!=15)$fatal(1,"loser transmitted");end
   else begin
    if(terminal_seen[idx])$fatal(1,"duplicate terminal ET %0d",idx);
    terminal_seen[idx]=1;terminals=terminals+1;
    if(idx==15&&kind!=2)$fatal(1,"winner failed %h",head);
    if(idx!=15&&(kind!=3||head[23:16]!=2))$fatal(1,"loser reason %h",head);
   end
   wr('h110,'h201);
  end
  if(starts!=1||tx_facts!=1||terminal_seen!=16'hffff)$fatal(1,"event counts");
  for(integer e=0;e<16;e=e+1)mh('h100+e*16,0);
  // Late submission and bad fine time are distinguishable terminal outcomes.
  configure(0,17);wr('h110,'h101);event_get(4,0);mh('h100,0);
  target=dut.now_slot+1;mw('h100,(target[15:0]<<16));mw('h104,{16'd0,2'd0,target[29:16]});mw('h108,'h400/2);mh('h100,8);
  do rd('h24,head);while(head[7:0]==0);if(head[15:12]!=3||head[23:16]!=1)$fatal(1,"late handling %h",head);wr('h110,'h201);mh('h100,0);
  target=dut.now_slot+20;mw('h100,(target[15:0]<<16));mw('h104,(250<<16)|target[29:16]);mw('h108,'h400/2);mh('h100,8);
  event_get(5,0);rd('h060,d);if(!d[1])$fatal(1,"BAD_TIME absent");mh('h100,0);wr('h060,31);
  // Missing external timing capabilities fail before touching the PHY.
  phy_caps=0;configure(0,17);event_get(5,0);mh('h100,0);phy_caps=15;
  $display("SLE_TEST_PASS: tb_scheduler");$finish;
 end
 initial begin #100000000;$display("pkt=%d sch=%d owned=%h fifo=%d errors=%b",dut.u_rw_ble_core.u_rw_ble_core_cntl.u_rw_ble_packet_cntl.state,dut.u_rw_cm_activity_scheduler.state,dut.owned,dut.fifo_count,dut.error_status);$fatal(1,"timeout");end
endmodule
