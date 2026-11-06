`timescale 1ns/1ps
module tb_board_axi;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0;reg [31:0] s_axi_awaddr=0,s_axi_wdata=0,s_axi_araddr=0;
 reg [2:0] s_axi_awprot=0,s_axi_arprot=0;reg [3:0] s_axi_wstrb=15;
 reg s_axi_awvalid=0,s_axi_wvalid=0,s_axi_bready=0,s_axi_arvalid=0,s_axi_rready=0;
 wire s_axi_awready,s_axi_wready,s_axi_bvalid,s_axi_arready,s_axi_rvalid;
 wire [1:0] s_axi_bresp,s_axi_rresp;wire [31:0] s_axi_rdata;wire [383:0] trace;
 sle_board_axi dut(.*);
 task aw(input [31:0] a);@(negedge clk);s_axi_awaddr=a;s_axi_awvalid=1;do @(posedge clk);while(!s_axi_awready);@(negedge clk);s_axi_awvalid=0;endtask
 task wd(input [31:0] d,input [3:0] b);@(negedge clk);s_axi_wdata=d;s_axi_wstrb=b;s_axi_wvalid=1;do @(posedge clk);while(!s_axi_wready);@(negedge clk);s_axi_wvalid=0;endtask
 task resp(input [1:0] e);
  wait(s_axi_bvalid);if(s_axi_bresp!==e)$fatal(1,"BRESP");
  repeat(7)begin @(negedge clk);if(!s_axi_bvalid||s_axi_bresp!==e)$fatal(1,"B backpressure");end
  s_axi_bready=1;@(negedge clk);s_axi_bready=0;
 endtask
 task readcheck(input [31:0] a,input [31:0] e,input [1:0] err);
  @(negedge clk);s_axi_araddr=a;s_axi_arvalid=1;do @(posedge clk);while(!s_axi_arready);
  @(negedge clk);s_axi_arvalid=0;wait(s_axi_rvalid);
  repeat(7)begin @(negedge clk);if(!s_axi_rvalid||s_axi_rdata!==e||s_axi_rresp!==err)$fatal(1,"R %h got %h %b",a,s_axi_rdata,s_axi_rresp);end
  s_axi_rready=1;@(negedge clk);s_axi_rready=0;
 endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;repeat(16)@(negedge clk);
  readcheck('h40040000,'h534c4254,0);readcheck('h40000004,'h534c0100,0);
  wd('h11223344,15);repeat(9)@(negedge clk);aw('h40025000);resp(0);readcheck('h40025000,'h11223344,0);
  aw('h40025000);repeat(9)@(negedge clk);wd('haa000000,8);resp(0);readcheck('h40025000,'haa223344,0);
  readcheck('h50000000,0,2);readcheck('h40000003,0,2);
  aw('h40050000);wd(0,15);resp(2);
  // Reset between independent AW and W must discard the old AW.
  aw('h40025000);@(negedge clk);rst_n=0;repeat(3)@(negedge clk);rst_n=1;repeat(16)@(negedge clk);
  wd('h55667788,15);aw('h40025004);resp(0);readcheck('h40025000,'haa223344,0);readcheck('h40025004,'h55667788,0);
  $display("SLE_TEST_PASS: tb_board_axi");$finish;
 end
 initial begin #2000000;$fatal(1,"AXI timeout");end
endmodule
