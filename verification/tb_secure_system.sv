`timescale 1ns/1ps
module tb_secure_system;
 `include "system_harness.vh"
 integer a,k,md,n;
 integer lens[0:2],cases[0:2];
 task security_config(input integer alg,input integer mode_value);
  wr('h800,(n<=251?9:18)|((mode_value==0?0:3)<<20)|((alg+1)<<16));
  wr('h830,32'h0c0d0e0f);wr('h834,32'h08090a0b);wr('h838,32'h04050607);wr('h83c,32'h00010203);
  wr('h840,32'h08070605);wr('h844,32'h0c0b0a09);wr('h848,32'h03020100);wr('h84c,4);wr('h850,0);
  wr('h828,32'h03020100);wr('h82c,4);
 endtask
 task publish_two_slots(input integer mode_value);
  target=dut.now_slot+2;target_fine_expect=dut.now_fine+24;
  if(target_fine_expect>=250)begin target=target+1;target_fine_expect=target_fine_expect-250;end
  mw('h100,(target[15:0]<<16)|(5<<11)|mode_value);
  mw('h104,(target_fine_expect<<16)|target[29:16]);
  mh('h100,(5<<11)|8|mode_value);
 endtask
 initial begin
  lens[0]=17;lens[1]=260;lens[2]=2043;cases[0]=4;cases[1]=6;cases[2]=7;
  phy_caps=15;hready_in=1;repeat(5)@(negedge clk);rst_n=1;
  wr('h02c,'h80);wr(0,1);wr('h110,1);
  // Maximum unencrypted data length at the minimum two-slot budget.
  configure(0,2047,0,0);publish_two_slots(0);event_get(1,0);event_get(6,0);event_get(2,0);mh('h100,0);
  for(a=0;a<2;a=a+1)for(md=0;md<2;md=md+1)for(k=0;k<3;k=k+1)begin
   n=lens[k];configure(md,n,k[0],0);security_config(a,md);
   secure_payload=1;oracle_case=a*8+cases[k];expected_length=n+4;rx_test_length=n+4;
   publish_two_slots(md);
   event_get(1,0);event_get(md==0?6:7,0);event_get(2,0);
   if(md==1)begin
    mr('h380c,d);if(d[4:0]!=31)$fatal(1,"secure RX outcomes alg=%0d n=%0d %h",a,n,d);
    for(i=0;i<n;i=i+1)begin
     mr(('h10800+(k[0]?2:0)+i)&~3,d);
     if(d[(('h10800+(k[0]?2:0)+i)%4)*8+:8]!==pattern(i))$fatal(1,"secure RX payload");
    end
   end
   mh('h100,0);secure_payload=0;
  end
  configure(1,17,0,0);security_config(0,1);secure_payload=1;oracle_case=4;expected_length=21;rx_test_length=21;tamper_mic=1;
  publish_two_slots(1);event_get(1,0);event_get(7,0);event_get(2,0);
  mr('h380c,d);if(d[4:0]!=7)$fatal(1,"MIC failure delivered %h",d);
  mr('h2800,d);if(!d[20])$fatal(1,"MIC_ERR absent");
  $display("SLE_TEST_PASS: tb_secure_system");$finish;
 end
 initial begin #150000000;$display("pkt=%d fifo=%d errors=%h",dut.u_rw_ble_core.u_rw_ble_core_cntl.u_rw_ble_packet_cntl.state,dut.fifo_count,dut.error_status);$fatal(1,"timeout");end
endmodule
