`timescale 1ns/1ps
// Supplied SLE V2.1.1 PDF pp535-536 (printed527-528), Appendix F.
module tb_appendix_f;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,store_we=0,read_req=0,start=0,algorithm=0,decrypt=0,encrypt_payload=1,mic_enable=1;
 reg [8:0] store_addr=0,read_addr=0;reg [31:0] store_data=0;reg [3:0] store_be=15;
 reg [127:0] key=128'h7803e5c608070000bd801cf3cf11a1f4;
 reg [103:0] nonce=104'h00007aef1b0000000000000000;
 reg [10:0] length=17;
 wire read_valid,busy,done,error,mic_ok;wire [31:0] read_data,mic_value;
 rw_cm_crypto_engine dut(.*);
 reg [167:0] expected;
 task launch(input bit dec);
  @(negedge clk);decrypt=dec;start=1;@(negedge clk);start=0;
  wait(done);#1;if(error||!mic_ok)$fatal(1,"Appendix F MIC alg=%d",algorithm);
 endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  for(integer alg=0;alg<2;alg=alg+1)begin
   algorithm=alg;
   expected=alg?168'h3e2346d3ca12d82c7e9b6eb405f148280afac9ba62:168'h7c5d84ab1228ff2c321d3ecfd23fee614e8a856a16;
   for(integer w=0;w<6;w=w+1)begin
    @(negedge clk);store_addr=w;store_data=0;
    for(integer b=0;b<4;b=b+1)if(w*4+b<17)store_data[b*8+:8]=w*4+b;
    store_we=1;@(negedge clk);store_we=0;
   end
   launch(0);
   for(integer w=0;w<6;w=w+1)begin
    @(negedge clk);read_addr=w;read_req=1;@(negedge clk);read_req=0;
    wait(read_valid);#1;
    for(integer b=0;b<4;b=b+1)if(w*4+b<21&&read_data[b*8+:8]!==expected[167-(w*4+b)*8-:8])
     $fatal(1,"Appendix F ciphertext alg=%d byte=%d",alg,w*4+b);
   end
   launch(1);
   for(integer w=0;w<5;w=w+1)begin
    @(negedge clk);read_addr=w;read_req=1;@(negedge clk);read_req=0;wait(read_valid);#1;
    for(integer b=0;b<4;b=b+1)if(w*4+b<17&&read_data[b*8+:8]!==8'(w*4+b))$fatal(1,"Appendix F plaintext");
   end
  end
  $display("SLE_TEST_PASS: tb_appendix_f");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
