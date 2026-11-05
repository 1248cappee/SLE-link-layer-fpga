`timescale 1ns/1ps
module tb_recovery;
 `include "system_harness.vh"
 task setup;
  wr('h02c,'h80);wr(0,1);wr('h110,1);
 endtask
 task soft_reset_test;
  wr(0,3);
  do rd(0,d);while(d[8]);
  rd('h24,d);if(d!=0)$fatal(1,"reset did not empty events");
  rd('h060,d);if(d!=0)$fatal(1,"reset errors %h",d);
  rd('h02c,d);if(d!=0)$fatal(1,"ETPTR not reset");
  for(integer e=0;e<16;e=e+1)begin mr('h100+e*16,d);if(d[5:3]!=0)$fatal(1,"ET %0d not FREE",e);end
 endtask
 initial begin
  phy_caps=15;hready_in=1;repeat(5)@(negedge clk);rst_n=1;setup();
  configure(0,17);event_get(1,0);wr('h110,'h101);event_get(6,0);event_get(4,0);mh('h100,0);
  configure(1,17);event_get(1,0);wr('h110,'h101);event_get(4,0);mh('h100,0);
  configure(1,17);event_get(1,0);soft_reset_test();setup();
  // Fill the event FIFO with genuine ordered packet completions. No internal
  // forcing or artificial push is used to exercise overflow recovery.
  configure(0,17);
  // Cancel the initial publication, then prepare a longer descriptor chain.
  wr('h110,'h101);event_get(4,0);mh('h100,0);
  mw('h430,20000);
  for(integer k=0;k<70;k=k+1)begin
   mw('h2000+k*16,k==69?0:('h2000+(k+1)*16)/2);mw('h2004+k*16,'h10000/2);mw('h2008+k*16,0);mw('h200c+k*16,0);
   mw('h3000+k*16,((k==69?0:('h3000+(k+1)*16)/2)<<16)|(('h2000+k*16)/2));
   mw('h3004+k*16,(2047<<16)|17);mw('h3008+k*16,air_ticks);mw('h300c+k*16,0);
  end
  target=dut.now_slot+20;mw('h100,(target[15:0]<<16));mw('h104,{16'd0,2'd0,target[29:16]});mw('h108,'h400/2);mh('h100,8);
  do rd('h060,d);while(!d[2]);
  rd('h24,head);if(head[7:0]!=64||head[15:12]!=1)$fatal(1,"overflow queue corrupt %h",head);
  soft_reset_test();setup();
  configure(0,17);event_get(1,0);event_get(6,0);event_get(2,0);
  $display("SLE_TEST_PASS: tb_recovery");$finish;
 end
 initial begin #150000000;$display("pkt=%d reset=%d fifo=%d errors=%h",dut.u_rw_ble_core.u_rw_ble_core_cntl.u_rw_ble_packet_cntl.state,dut.reset_state,dut.fifo_count,dut.error_status);$fatal(1,"timeout");end
endmodule
