`timescale 1ns/1ps
module tb_resources;
 `include "system_harness.vh"
 task publish;
  target=dut.now_slot+20;mw('h100,(target[15:0]<<16)|(5<<11));mw('h104,target[29:16]);mh('h100,(5<<11)|8);
 endtask
 task retire_error;
  publish();event_get(5,0);rd('h060,d);if(!d[0])$fatal(1,"BAD_DESC missing");mh('h100,0);wr('h060,31);
 endtask
 initial begin
  phy_caps=15;hready_in=1;repeat(5)@(negedge clk);rst_n=1;
  wr('h02c,'h80);wr(0,1);wr('h110,1);
  configure(0,17,0,0);mw('h108,0);retire_error();
  configure(0,17,0,0);mw('h108,'h3fff);retire_error();
  configure(0,17,0,0);mw('h424,'h7ff8/2);retire_error();
  configure(0,261,0,0);mw('h3004,(260<<16)|261);retire_error();
  configure(0,17,0,0);mw('h3004,(2047<<16)|2048);retire_error();
  configure(0,2047,0,0);wr('h800,18|(1<<16));retire_error();
  configure(0,17,0,0);mw('h2004,'hffff);retire_error();
  configure(0,17,0,0);mw('h2004,0);retire_error();
  configure(0,17,0,0);mw('h3000,'h2100/2);retire_error();
  // Extension context is immutable after the READY handoff.
  configure(0,17);bus(1,'h800,9,15,d,1);wr('h110,'h101);event_get(4,0);mh('h100,0);wr('h060,31);
  // Zero-byte data is legal for a suitable control format; no RAM payload read.
  configure(0,0);event_get(1,0);event_get(6,0);event_get(2,0);mh('h100,0);
  wr('h110,0);wr(0,0);wr('h02c,'h3f80);rd('h02c,d);if(d!='h3f80)$fatal(1,"ET boundary exact end");
  $display("SLE_TEST_PASS: tb_resources");$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
