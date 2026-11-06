`timescale 1ns/1ps
module tb_cm_cdc;
 reg src_clk=0,dst_clk=0,src_rst_n=0,dst_rst_n=0,src_pulse=0;
 always #7.5 src_clk=~src_clk;
 always #11.3 dst_clk=~dst_clk;
 reg [39:0] src_data=0;
 wire src_ready,src_overflow,dst_pulse;wire [39:0] dst_data;
 pulse_to_pulse_synchro crossing(.*);
 reg [3:0] onehot=0;wire [3:0] onehot_value;wire onehot_error;
 reg edge_input=0;wire rise,fall,level;
 integer rises=0,falls=0;
 onehot_synchro onehot_dut(.clk(dst_clk),.rst_n(dst_rst_n),.async_in(onehot),.sync_out(onehot_value),.illegal(onehot_error));
 dual_edges_synchro edge_dut(.clk(dst_clk),.rst_n(dst_rst_n),.async_in(edge_input),.rise(rise),.fall(fall),.level(level));
 always @(negedge dst_clk)begin if(rise)rises=rises+1;if(fall)falls=falls+1;end
 integer received=0;
 always @(negedge dst_clk)if(dst_rst_n&&dst_pulse)begin
  if(dst_data!==((40'h5aabc00000+received)^40'h12345))$fatal(1,"CDC corrupt/duplicate index=%d data=%h",received,dst_data);
  received=received+1;
 end
 initial begin
  repeat(5)@(negedge src_clk);src_rst_n=1;dst_rst_n=1;
  for(integer i=0;i<200;i=i+1)begin
   wait(src_ready);@(negedge src_clk);src_data=(40'h5aabc00000+i)^40'h12345;src_pulse=1;
   @(negedge src_clk);src_pulse=0;wait(!src_ready);wait(src_ready);
  end
  repeat(10)@(negedge dst_clk);
  if(received!=200||src_overflow)$fatal(1,"CDC lost pulse");
  // Common reset epoch cancels any outstanding transfer without replay.
  src_rst_n=0;dst_rst_n=0;repeat(8)@(negedge src_clk);src_rst_n=1;dst_rst_n=1;
  repeat(10)@(negedge dst_clk);if(dst_pulse)$fatal(1,"stale CDC response");
  onehot=4'b0100;edge_input=1;repeat(8)@(negedge dst_clk);
  if(onehot_value!=4||onehot_error||rises!=1)$fatal(1,"onehot/rise");
  onehot=4'b1100;edge_input=0;repeat(8)@(negedge dst_clk);
  if(onehot_value!=0||!onehot_error||falls!=1)$fatal(1,"onehot/fall");
  $display("SLE_TEST_PASS: tb_cm_cdc");$finish;
 end
 initial begin #1000000;$fatal(1,"CDC timeout");end
endmodule
