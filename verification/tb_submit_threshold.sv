`timescale 1ns/1ps
module tb_submit_threshold;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,commit=0;
 reg [29:0] now_slot=100;reg [9:0] now_fine=10;
 wire em_req,em_write;wire [16:0] em_addr;wire [31:0] em_wdata;wire [3:0] em_be;
 reg em_ack=0;reg [31:0] em_rdata=0;reg held=0;
 reg [31:0] ram[0:127];
 wire job_valid,event_valid;wire [71:0] event_data;
 rw_cm_activity_scheduler dut(.clk(clk),.rst_n(rst_n),.enable(1'b1),.freeze(1'b0),.etptr(14'h80),
  .now_slot(now_slot),.now_fine(now_fine),.commit(commit),.commit_index(4'd0),.commit_slot(now_slot),.commit_fine(now_fine),
  .cancel(1'b0),.cancel_index(4'd0),.terminal_pop(1'b0),.pop_index(4'd0),.clear_start(1'b0),
  .em_req(em_req),.em_write(em_write),.em_addr(em_addr),.em_wdata(em_wdata),.em_be(em_be),.em_ack(em_ack),.em_fault(1'b0),.em_rdata(em_rdata),
  .job_valid(job_valid),.job_ready(1'b0),.engine_idle(1'b1),.engine_running(1'b0),.engine_started(1'b0),.engine_done(1'b0),.engine_abandoned(1'b0),
  .actual_start_slot(30'd0),.actual_start_fine(10'd0),.engine_status(3'd0),.engine_reason(8'd0),.event_valid(event_valid),.event_ready(1'b0));
 always @(posedge clk)begin
  em_ack<=0;
  if(!rst_n)held<=0;
  else if(em_req&&!held)begin
   held<=1;em_ack<=1;em_rdata<=ram[em_addr[8:2]];
   if(em_write)for(integer b=0;b<4;b=b+1)if(em_be[b])ram[em_addr[8:2]][b*8+:8]<=em_wdata[b*8+:8];
  end else if(!em_req)held<=0;
 end
 task trial(input [29:0] current,target,input [9:0] target_fine,input bit accepted);
  @(negedge clk);rst_n=0;commit=0;now_slot=current;
  for(integer k=0;k<128;k=k+1)ram[k]=0;
  ram[64]=(target[15:0]<<16)|(5<<11)|8;ram[65]=(target_fine<<16)|target[29:16];ram[66]='h200;
  repeat(3)@(negedge clk);rst_n=1;commit=1;@(negedge clk);commit=0;
  repeat(150)@(negedge clk);
  if(accepted)begin if(!job_valid||event_valid||ram[64][5:3]!=2)$fatal(1,"legal submission rejected");end
  else if(!event_valid||event_data[15:8]!=1||event_data[7:4]!=3||ram[64][5:3]!=5)$fatal(1,"late submission accepted");
 endtask
 initial begin
  trial(100,102,10,1); // exactly500 fine ticks
  trial(100,102,9,0);  //499
  trial(100,102,11,1); //501
  trial(30'h3fffffff,1,10,1); // wrap: still500
  trial(100,30'h20000064,10,0); // half-range ambiguity
  $display("SLE_TEST_PASS: tb_submit_threshold");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
