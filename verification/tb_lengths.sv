`timescale 1ns/1ps
module tb_lengths;
 `include "system_harness.vh"
 integer sizes[0:5];integer k,n,md;
 initial begin
  sizes[0]=1;sizes[1]=255;sizes[2]=256;sizes[3]=260;sizes[4]=261;sizes[5]=2047;
  phy_caps=15;hready_in=1;repeat(5)@(negedge clk);rst_n=1;
  wr('h02c,'h80);wr(0,1);wr('h110,1);
  for(md=0;md<2;md=md+1)for(k=0;k<6;k=k+1)begin
   n=sizes[k];
   configure(md,n,k[0]);
   if(md==1)begin
    // Exact-byte guard immediately after the allocated logical frame.
    bus(1,18'h20000+(('h10800+(k[0]?2:0)+n)&~3),32'h5a5a5a5a,15,d);
   end
   event_get(1,0);event_get(md==0?6:7,0);event_get(2,0);
   if(md==1)begin
    for(i=0;i<n;i=i+1)begin
     mr(('h10800+(k[0]?2:0)+i)&~3,d);
     if(d[(('h10800+(k[0]?2:0)+i)%4)*8+:8]!==pattern(i))$fatal(1,"RX length=%0d byte=%0d",n,i);
    end
    mr(('h10800+(k[0]?2:0)+n)&~3,d);
    if(d[(('h10800+(k[0]?2:0)+n)%4)*8+:8]!==8'h5a)$fatal(1,"RX overrun n=%0d",n);
   end
   mh('h100,0);
  end
  good_crc=0;configure(1,17);event_get(1,0);event_get(7,0);event_get(2,0);
  mr('h2800,d);if(!d[19]||!d[15])$fatal(1,"CRC failed frame not recorded");
  mr('h380c,d);if(d[4]||d[1]||!d[0])$fatal(1,"CRC failure reported successful %h",d);
  mh('h100,0);good_crc=1;duplicate_frame=1;
  configure(1,17);event_get(1,0);event_get(7,0);event_get(2,0);
  mr('h380c,d);if(d[4:0]!=3)$fatal(1,"duplicate frame delivered %h",d);
  mr('h3808,d);if(!d[8])$fatal(1,"duplicate metadata lost");
  $display("SLE_TEST_PASS: tb_lengths");$finish;
 end
 initial begin #200000000;$display("pkt=%d fifo=%d errors=%b",dut.u_rw_ble_core.u_rw_ble_core_cntl.u_rw_ble_packet_cntl.state,dut.fifo_count,dut.error_status);$fatal(1,"timeout");end
endmodule
