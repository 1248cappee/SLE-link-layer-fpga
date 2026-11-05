`timescale 1ns/1ps
module tb_primitives;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,start=0,algorithm=0;
 reg [127:0] key=0,block_in=0;
 wire busy,done;wire [127:0] block_out;
 sle_block_cipher dut(.*);
 reg cmac_start=0;
 reg [127:0] message=0;
 reg [4:0] message_bytes=0;
 wire cmac_busy,cmac_done,cmac_error;wire [127:0] cmac_result;
 sle_cmac cmac(.clk(clk),.rst_n(rst_n),.start(cmac_start),.algorithm(algorithm),.key(key),.message(message),.message_bytes(message_bytes),
 .busy(cmac_busy),.done(cmac_done),.error(cmac_error),.result(cmac_result));
 task block_test(input bit alg,input [127:0] k,p,e);
  @(negedge clk);algorithm=alg;key=k;block_in=p;start=1;
  @(negedge clk);start=0;
  wait(done);#1;if(block_out!==e)$fatal(1,"block alg=%0d got %032h expected %032h",alg,block_out,e);
  @(negedge clk);
 endtask
 task cmac_test(input [4:0] n,input [127:0] m,e);
  @(negedge clk);algorithm=0;key=128'h2b7e151628aed2a6abf7158809cf4f3c;message_bytes=n;message=m;cmac_start=1;
  @(negedge clk);cmac_start=0;
  wait(cmac_done);#1;if(cmac_error||cmac_result!==e)$fatal(1,"CMAC n=%0d got %032h expected %032h",n,cmac_result,e);
  @(negedge clk);
 endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  block_test(0,128'h000102030405060708090a0b0c0d0e0f,128'h00112233445566778899aabbccddeeff,128'h69c4e0d86a7b0430d8cdb78070b4c55a);
  block_test(1,128'h0123456789abcdeffedcba9876543210,128'h0123456789abcdeffedcba9876543210,128'h681edf34d206965e86b3e94f536e4246);
  cmac_test(0,0,128'hbb1d6929e95937287fa37d129b756746);
  cmac_test(16,128'h6bc1bee22e409f96e93d7e117393172a,128'h070a16b46b4d4144f79bdd9dd04a287c);
  $display("SLE_TEST_PASS: tb_primitives");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
