`timescale 1ns/1ps
// Independent ciphertext oracle, parameter-dependent latency, transaction
// ownership, stable output, busy-start rejection and reset recovery.
module tb_cm_cipher;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,start=0,algorithm=0,inject=0;
 reg [127:0] key=0,block_in=0;
 wire [3:0] busy,done;wire [127:0] result[0:3];
 reg [383:0] vectors[0:65];reg [127:0] previous[0:3];
 integer a_steps[0:3],s_steps[0:3];integer i,j,cycle,latency;
 reg saved_algorithm;reg [127:0] expected;
 genvar g;
 generate for(g=0;g<4;g=g+1) begin:engines
  localparam integer A=(g==0)?1:(g==1)?2:(g==2)?3:10;
  localparam integer S=(g==0)?1:(g==1)?4:(g==2)?7:32;
  sle_block_cipher #(.AES_STEPS(A),.SM4_STEPS(S)) dut(
   .clk(clk),.rst_n(rst_n),.start(start | (inject && busy[g])),.algorithm(algorithm),
   .key(key),.block_in(block_in),.busy(busy[g]),.done(done[g]),.block_out(result[g]));
 end endgenerate
 task run_vector(input integer index);
  begin
   @(negedge clk);start=1;inject=0;algorithm=index&1;saved_algorithm=algorithm;
   key=vectors[index][383:256];block_in=vectors[index][255:128];expected=vectors[index][127:0];
   @(posedge clk);#1;
   if(busy!==4'b1111 || done!==0)$fatal(1,"start ownership vector=%0d",index);
   for(j=0;j<4;j=j+1) if(result[j]!==previous[j])$fatal(1,"output changed before DONE");
   @(negedge clk);start=0;inject=1;algorithm=~algorithm;key=~key;block_in=~block_in;
   for(cycle=1;cycle<=33;cycle=cycle+1) begin
    @(posedge clk);#1;
    for(j=0;j<4;j=j+1) begin
     latency=saved_algorithm?(32+s_steps[j]-1)/s_steps[j]:(10+a_steps[j]-1)/a_steps[j];
     if(done[j] !== (cycle==latency))$fatal(1,"completion latency vector=%0d engine=%0d cycle=%0d",index,j,cycle);
     if(busy[j] !== (cycle<latency))$fatal(1,"busy ownership vector=%0d engine=%0d",index,j);
     if(cycle<latency && result[j]!==previous[j])$fatal(1,"in-flight result corrupted");
     if(cycle>=latency && result[j]!==expected)$fatal(1,"cipher vector=%0d engine=%0d got=%h expected=%h",index,j,result[j],expected);
    end
   end
   for(j=0;j<4;j=j+1) previous[j]=expected;
   @(negedge clk);inject=0;
  end
 endtask
 initial begin
  $readmemh("cm_cipher.mem",vectors);
  a_steps[0]=1;a_steps[1]=2;a_steps[2]=3;a_steps[3]=10;
  s_steps[0]=1;s_steps[1]=4;s_steps[2]=7;s_steps[3]=32;
  for(j=0;j<4;j=j+1)previous[j]=0;
  repeat(4)@(negedge clk);rst_n=1;
  for(i=0;i<66;i=i+1)run_vector(i);
  // Fast engine accepts a new algorithm on the edge immediately after DONE,
  // with no idle bubble. Its output must keep the just-completed old result.
  for(i=0;i<8;i=i+1)begin
   @(negedge clk);start=1;algorithm=i&1;key=vectors[i][383:256];block_in=vectors[i][255:128];
   @(posedge clk);#1;
   if(!busy[3] || done[3] || result[3]!==previous[3])$fatal(1,"back-to-back ownership/result");
   @(negedge clk);start=0;
   @(posedge clk);#1;
   if(busy[3] || !done[3] || result[3]!==vectors[i][127:0])$fatal(1,"back-to-back ciphertext");
   previous[3]=result[3];
  end
  // Reset an unfinished operation; a following operation must not see its
  // key, result, completion pulse or retained algorithm selection.
  @(negedge clk);start=1;algorithm=1;key=vectors[1][383:256];block_in=vectors[1][255:128];
  @(negedge clk);start=0;rst_n=0;
  repeat(3)@(negedge clk);
  if(busy!==0 || done!==0)$fatal(1,"reset left active ownership");
  for(j=0;j<4;j=j+1)begin
   if(result[j]!==0)$fatal(1,"reset retained prior result");previous[j]=0;
  end
  rst_n=1;run_vector(0);run_vector(1);
  $display("SLE_TEST_PASS: tb_cm_cipher");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
