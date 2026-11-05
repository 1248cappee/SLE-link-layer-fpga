`timescale 1ns/1ps
module tb_registers;
 `include "system_harness.vh"
 reg [11:0] offsets[0:103];reg [31:0] before_time;
 initial begin
  $readmemh("register_offsets.mem",offsets);
  phy_caps=15;hready_in=1;repeat(5)@(negedge clk);rst_n=1;
  // Read every address in the supplied register directory.
  for(integer k=0;k<104;k=k+1)begin
   rd(offsets[k],d);
   if(offsets[k]==4)begin if(d!==32'h534c0100)$fatal(1,"VERSION reset");end
   else if(offsets[k]==8)begin if(d!==32'h00100f01)$fatal(1,"RWBLECONF reset");end
   else if(d!==0)$fatal(1,"register reset offset=%h value=%h",offsets[k],d);
  end
  for(integer k=0;k<512;k=k+1)begin rd('h800+k*4,d);if(d!==0)$fatal(1,"extension reset");end
  bus(1,4,32'h12345678,15,d,1);rd(4,d);if(d!==32'h534c0100)$fatal(1,"RO changed");wr('h060,16);
  bus(1,'h02c,'h3ff8,15,d,1);bus(1,'h02c,1,15,d,1);wr('h060,16);
  wr('h02c,'h80);
  wr('h040,100);wr('h044,7);wr('h0e0,'h200);
  wr('h0e0,'h100);rd('h100,before_time);rd('h104,d);
  if(before_time!=7||d<100||d>110)$fatal(1,"time load/snapshot");
  repeat(300)@(negedge clk);rd('h100,d);if(d!=before_time)$fatal(1,"snapshot not retained");
  wr('h0e8,100);wr('h0ec,249);wr('h0e0,1);
  bus(1,'h0ec,0,15,d,1);rd('h0ec,d);if(d!=249)$fatal(1,"armed target modified");
  bus(1,'h0e0,'h201,15,d,1);wr('h0e0,0);wr('h060,16);
  wr('h0e8,0);wr('h0ec,0);wr('h0e0,1);repeat(5)@(negedge clk);
  rd('h010,d);if(!d[1])$fatal(1,"past timer not latched");
  rd('h0e0,d);if(d[0])$fatal(1,"one shot still armed");
  wr('h014,2);rd('h010,d);if(d[1])$fatal(1,"W1C failed");
  rd('h014,d);if(d!=0)$fatal(1,"W1C readback not zero");
  bus(1,'h110,'h200,15,d,1);rd('h024,d);if(d!=0)$fatal(1,"empty POP underflow");
  $display("SLE_TEST_PASS: tb_registers");$finish;
 end
 initial begin #5000000;$fatal(1,"timeout");end
endmodule
