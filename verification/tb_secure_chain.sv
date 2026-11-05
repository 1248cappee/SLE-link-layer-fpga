`timescale 1ns/1ps
module tb_secure_chain;
 `include "system_harness.vh"
 reg [31:0] next_oracle[0:1023];
 integer cfg_count=0,rx_count=0,a,md;
 always @(posedge clk)begin
  if(tx_cfg_valid&&tx_cfg_ready)begin oracle_case<=cfg_count==0?a*8+4:5;cfg_count<=cfg_count+1;end
  if(rx_req&&rx_write&&rx_addr==0&&rx_wdata[1])begin oracle_case<=rx_count==0?a*8+4:5;rx_count<=rx_count+1;end
 end
 initial begin
  $readmemh("secure_chain.mem",next_oracle);
  phy_caps=15;hready_in=1;repeat(5)@(negedge clk);rst_n=1;
  wr('h02c,'h80);wr(0,1);wr('h110,1);
  for(a=0;a<2;a=a+1)for(md=0;md<2;md=md+1)begin
   cfg_count=0;rx_count=0;configure(md,17,0,0);
   for(integer k=0;k<512;k=k+1)security_oracle[5*512+k]=next_oracle[a*512+k];
   wr('h800,9|((md==0?0:3)<<20)|((a+1)<<16));
   wr('h830,32'h0c0d0e0f);wr('h834,32'h08090a0b);wr('h838,32'h04050607);wr('h83c,32'h00010203);
   wr('h840,32'h08070605);wr('h844,32'h0c0b0a09);wr('h848,32'h03020100);wr('h84c,4);wr('h850,0);
   wr('h828,32'h03020100);wr('h82c,4);
   if(md==0)begin
    for(integer k=0;k<4;k=k+1)mw('h2100+k*4,0);
    mw('h2000,'h2100/2);mw('h2104,'h10000/2);
    mw('h3000,(('h3100/2)<<16)|('h2000/2));
    mw('h3100,'h2100/2);mw('h3104,(2047<<16)|17);mw('h3108,air_ticks);mw('h310c,0);
   end else begin
    for(integer k=0;k<7;k=k+1)mw('h2900+k*4,0);
    mw('h2800,'h2900/2);mw('h2914,'h10800/2);
    mw('h3800,(('h3900/2)<<16)|('h2800/2));
    mw('h3900,'h2900/2);mw('h3904,(2047<<16));mw('h3908,0);mw('h390c,0);
   end
   secure_payload=1;expected_length=21;rx_test_length=21;oracle_case=a*8+4;
   target=dut.now_slot+20;mw('h100,(target[15:0]<<16)|(5<<11)|md);mw('h104,target[29:16]);mh('h100,(5<<11)|8|md);
   event_get(1,0);event_get(md==0?6:7,0);event_get(md==0?6:7,0);event_get(2,0);
   if(md==1)begin mr('h380c,d);if(d[4:0]!=31)$fatal(1,"first secure RX");mr('h390c,d);if(d[4:0]!=31)$fatal(1,"second secure RX counter");end
   mh('h100,0);secure_payload=0;
  end
  $display("SLE_TEST_PASS: tb_secure_chain");$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
