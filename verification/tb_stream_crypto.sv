`timescale 1ns/1ps
module tb_stream_crypto;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,start=0,algorithm=0,auth_only=0,s_valid=0,m_ready=0;
 reg [127:0] key=128'h000102030405060708090a0b0c0d0e0f;
 reg [103:0] nonce=104'h000102030405060708090a0b0c;
 reg [10:0] length=0;reg [31:0] s_data=0;
 wire s_ready,m_valid,m_last,busy,done,error;wire [31:0] m_data;wire [3:0] m_keep;
 sle_ccm_stream_tx dut(.*);
 reg [31:0] oracle[0:8191];integer lengths[0:7];integer a,k,n,i,j,received=0,cycle=0;
 reg [31:0] held_data;reg [3:0] held_keep;reg held_last,stalled=0;
 function [7:0] plain(input integer n);plain=(n*37+11)&255;endfunction
 always @(posedge clk)begin
  cycle<=cycle+1;m_ready<=cycle%7!=0;
  if(stalled)begin if(!m_valid||m_data!==held_data||m_keep!==held_keep||m_last!==held_last)$fatal(1,"stream output moved while stalled");end
  stalled<=m_valid&&!m_ready;held_data<=m_data;held_keep<=m_keep;held_last<=m_last;
  if(m_valid&&m_ready)begin
   for(integer b=0;b<4;b=b+1)if(m_keep[b])begin
    if(m_data[b*8+:8]!==oracle[(a*8+k)*512+received/4][(received%4)*8+:8])$fatal(1,"stream alg=%0d n=%0d byte=%0d",a,n,received);
    received=received+1;
   end
   if(m_last&&received!=n+4)$fatal(1,"stream last/length");
  end
 end
 initial begin
  $readmemh("aes_sm4_ccm.mem",oracle);
  lengths[0]=0;lengths[1]=1;lengths[2]=15;lengths[3]=16;lengths[4]=17;lengths[5]=31;lengths[6]=260;lengths[7]=2043;
  repeat(4)@(negedge clk);rst_n=1;
  for(a=0;a<2;a=a+1)for(k=0;k<8;k=k+1)begin
   @(negedge clk);algorithm=a;n=lengths[k];length=n;received=0;start=1;@(negedge clk);start=0;
   for(i=0;i<(n+3)/4;i=i+1)begin
    repeat(i%3)@(negedge clk);
    s_data=0;for(j=0;j<4;j=j+1)if(i*4+j<n)s_data[j*8+:8]=plain(i*4+j);
    s_valid=1;do @(posedge clk);while(!s_ready);@(negedge clk);s_valid=0;
   end
   wait(done);#1;if(error||received!=n+4)$fatal(1,"stream final error/length");@(negedge clk);
  end
  $display("SLE_TEST_PASS: tb_stream_crypto");$finish;
 end
 initial begin #100000000;$fatal(1,"timeout");end
endmodule
