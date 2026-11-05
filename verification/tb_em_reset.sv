`timescale 1ns/1ps
module tb_em_reset;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0;reg [2:0] req=0,write=0;reg [50:0] addr=0;reg [95:0] wdata=0;reg [11:0] be=0;
 wire [2:0] ack,fault;wire [31:0] rdata;wire busy;
 rw_ble_em_cntl #(.EM_BYTES(1024)) dut(.*);
 reg [31:0] value;integer phase;
 task access(input bit wr,input [16:0] a,input [31:0] d,output [31:0] q);
  @(negedge clk);req=1;write=wr;addr=a;wdata=d;be=15;
  wait(ack[0]);#1;q=rdata;if(fault)$fatal(1,"unexpected EM fault");
  @(negedge clk);req=0;repeat(3)@(negedge clk);
 endtask
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  for(phase=0;phase<4;phase=phase+1)begin
   access(1,4,'hcafe1234,value);access(1,8,'h55aa55aa,value);
   @(negedge clk);req=1;write=1;addr=4;wdata='h11223344;be=15;
   if(phase!=0)begin wait(dut.state==phase);@(negedge clk);end
   rst_n=0;req=0;repeat(3)@(negedge clk);rst_n=1;
   repeat(5)begin @(negedge clk);if(ack||fault||busy)$fatal(1,"stale response after reset phase=%0d",phase);end
   access(0,4,0,value);
   if(value!==(phase==0?32'hcafe1234:32'h11223344))$fatal(1,"accepted write/reset contract phase=%0d value=%h",phase,value);
   access(0,8,0,value);if(value!=='h55aa55aa)$fatal(1,"stray write after reset");
  end
  $display("SLE_TEST_PASS: tb_em_reset");$finish;
 end
 initial begin #1000000;$fatal(1,"EM reset timeout");end
endmodule
