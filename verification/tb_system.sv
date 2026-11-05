`timescale 1ns/1ps
module tb_system;
 `include "system_harness.vh"
 initial begin
  phy_caps=15;hready_in=1;
  repeat(5)@(negedge clk);rst_n=1;
  rd('h004,d);if(d!==32'h534c0100)$fatal(1,"VERSION");
  wr('h02c,'h80);wr('h00c,'h3f);wr(0,1);wr('h110,1);
  bus(1,'h040,250,15,d,1);rd('h060,d);if(!d[4])$fatal(1,"BAD_CMD not latched");wr('h060,16);
  // Byte write and registered EM response contract.
  mw('h5000,32'h11223344);bus(1,'h25000,32'haa000000,8,d);mr('h5000,d);if(d!==32'haa223344)$fatal(1,"EM byte enables");
  for(mode_test=0;mode_test<4;mode_test=mode_test+1)begin
   configure(mode_test,17,mode_test[0]);
   event_get(1,0);
   if(mode_test==0)event_get(6,0);
   if(mode_test==1)event_get(7,0);
   if(mode_test==2)begin event_get(6,0);event_get(7,0);end
   if(mode_test==3)begin event_get(7,0);event_get(6,0);end
   event_get(2,0);
   if(mode_test!=1)begin mr('h2000,d);if(!d[15])$fatal(1,"TXDONE missing");end
   if(mode_test!=0)begin
    mr('h2800,d);if(!d[15]||d[31:16]!=0)$fatal(1,"RXDONE/status %h",d);
    mr('h380c,d);if(d[4:0]!=5'b10011)$fatal(1,"RX independent outcomes %b",d[4:0]);
    for(i=0;i<17;i=i+1)begin
     mr(('h10800+(mode_test[0]?2:0)+i)&~3,d);
     if(d[(('h10800+(mode_test[0]?2:0)+i)%4)*8+:8]!==pattern(i))$fatal(1,"RX payload byte %0d",i);
    end
   end
   mh('h100,0);
  end
  configure(0,2047);event_get(1,0);event_get(6,0);event_get(2,0);mh('h100,0);
  $display("SLE_TEST_PASS: tb_system");$finish;
 end
 initial begin #100000000;$display("state packet=%d scheduler=%d errors=%b fifo=%d",dut.u_rw_ble_core.u_rw_ble_core_cntl.u_rw_ble_packet_cntl.state,dut.u_rw_cm_activity_scheduler.state,dut.error_status,dut.fifo_count);$fatal(1,"timeout");end
endmodule
