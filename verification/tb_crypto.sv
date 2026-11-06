`timescale 1ns/1ps
module tb_crypto;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,store_we=0,read_req=0,start=0,algorithm=0,decrypt=0,encrypt_payload=1,mic_enable=1;
 reg [8:0] store_addr=0,read_addr=0;reg [31:0] store_data=0;reg [3:0] store_be=0;
 reg [127:0] key=128'h000102030405060708090a0b0c0d0e0f;
 reg [103:0] nonce=104'h000102030405060708090a0b0c;
 reg [10:0] length=0;
 wire read_valid,busy,done,error,mic_ok;wire [31:0] read_data,mic_value;
 rw_cm_crypto_engine dut(.*);
 reg [31:0] oracle[0:8191];integer lengths[0:7];integer a,k,n,i,j;
 reg [31:0] value,got,expected;
 function [7:0] plain(input integer i);plain=(i*37+11)&255;endfunction
 task put(input integer address,input [31:0] data);
  @(negedge clk);store_addr=address;store_data=data;store_be=15;store_we=1;
  @(negedge clk);store_we=0;
 endtask
 task get(input integer address,output [31:0] data);
  @(negedge clk);read_addr=address;read_req=1;
  @(negedge clk);read_req=0;
  wait(read_valid);#1;data=read_data;
 endtask
 task launch(input bit dec);
  @(negedge clk);decrypt=dec;start=1;@(negedge clk);start=0;
  // Idle host port cannot steal a read or overwrite payload during CCM.
  read_req=1;read_addr=511;store_we=1;store_addr=0;store_data=32'hbad0bad0;store_be=15;
  repeat(3)begin @(posedge clk);#1;if(read_valid)$fatal(1,"busy host read accepted");end
  @(negedge clk);read_req=0;store_we=0;
  wait(done);#1;if(error)$fatal(1,"crypto error alg=%0d n=%0d",algorithm,length);
 endtask
 initial begin
  $readmemh("aes_sm4_ccm.mem",oracle);
  lengths[0]=0;lengths[1]=1;lengths[2]=15;lengths[3]=16;lengths[4]=17;lengths[5]=31;lengths[6]=260;lengths[7]=2043;
  repeat(4)@(negedge clk);rst_n=1;
  put(0,32'h11223344);
  @(negedge clk);store_addr=0;store_data=32'haabbccdd;store_be=5;store_we=1;
  @(negedge clk);store_we=0;
  get(0,got);if(got!==32'h11bb33dd)$fatal(1,"CCM byte write lost lanes");
  // Same-edge read/write returns the previous word (read-first).
  @(negedge clk);read_req=1;read_addr=0;store_we=1;store_addr=0;store_data=32'hdeadbeef;store_be=15;
  @(posedge clk);#1;if(read_valid)$fatal(1,"CCM response before registered RAM edge");
  @(negedge clk);read_req=0;store_we=0;
  @(posedge clk);#1;if(!read_valid||read_data!==32'h11bb33dd)$fatal(1,"CCM read-first contract");
  get(0,got);if(got!==32'hdeadbeef)$fatal(1,"CCM simultaneous write not committed");
  put(511,32'hc0debeef);
  @(negedge clk);rst_n=0;repeat(3)@(negedge clk);
  if(read_valid || busy || done)$fatal(1,"CCM reset left old response");
  rst_n=1;get(511,got);if(got!==32'hc0debeef)$fatal(1,"CCM reset cleared BRAM content");
  // Cancel an accepted read before the physical RAM edge: its old validity
  // must not reappear after reset. Contents remain available to a new read.
  @(negedge clk);read_req=1;read_addr=511;
  @(posedge clk);#1;if(read_valid)$fatal(1,"CCM read completed before RAM edge");
  @(negedge clk);read_req=0;rst_n=0;repeat(3)@(negedge clk);
  rst_n=1;
  repeat(3)begin @(posedge clk);#1;if(read_valid)$fatal(1,"old CCM read crossed reset");end
  get(511,got);if(got!==32'hc0debeef)$fatal(1,"CCM retained word lost after read abort");
  // Abort both algorithms during computation; the following independent CCM
  // vectors must recover without an old completion, key or partial MAC.
  for(a=0;a<2;a=a+1)begin
   @(negedge clk);algorithm=a;length=17;start=1;
   @(negedge clk);start=0;repeat(5)@(negedge clk);
   if(!busy)$fatal(1,"CCM reset test did not enter computation");
   rst_n=0;repeat(3)@(negedge clk);rst_n=1;
   repeat(4)begin @(posedge clk);#1;if(busy||done||read_valid)$fatal(1,"stale CCM operation after reset");end
  end
  for(a=0;a<2;a=a+1) for(k=0;k<8;k=k+1) begin
   algorithm=a;n=lengths[k];length=n;
   for(i=0;i<(n+7)/4;i=i+1) begin
    value=0;for(j=0;j<4;j=j+1) if(i*4+j<n)value[j*8+:8]=plain(i*4+j);
    put(i,value);
   end
   launch(0);if(!mic_ok)$fatal(1,"TX MIC result missing");
   for(i=0;i<(n+7)/4;i=i+1) begin
    get(i,got);expected=oracle[(a*8+k)*512+i];
    for(j=0;j<4;j=j+1) if(i*4+j<n+4&&got[j*8+:8]!==expected[j*8+:8])
     $fatal(1,"encrypt alg=%0d n=%0d byte=%0d got=%h expected=%h",a,n,i*4+j,got,expected);
   end
   launch(1);if(!mic_ok)$fatal(1,"valid MIC rejected alg=%0d n=%0d",a,n);
   for(i=0;i<(n+3)/4;i=i+1) begin
    get(i,got);for(j=0;j<4;j=j+1) if(i*4+j<n&&got[j*8+:8]!==plain(i*4+j))$fatal(1,"decrypt payload mismatch");
   end
   // Refill independently generated ciphertext, corrupt exactly one MIC bit.
   for(i=0;i<(n+7)/4;i=i+1) begin value=oracle[(a*8+k)*512+i];if(i==n/4)value=value^(32'd1<<((n%4)*8));put(i,value);end
   launch(1);if(mic_ok)$fatal(1,"corrupt MIC accepted alg=%0d n=%0d",a,n);
  end
  $display("SLE_TEST_PASS: tb_crypto");$finish;
 end
 initial begin #200000000;$fatal(1,"timeout");end
endmodule
