`timescale 1ns/1ps
module tb_board_suite;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,host_req=0,host_write=0;reg [18:0] host_addr=0;
 reg [31:0] host_wdata=0;reg [3:0] host_be=15;
 wire host_wait,host_error;wire [31:0] host_rdata;wire [383:0] trace;
 sle_board_core dut(.*);
 // These are the physical ILA bit positions used by the JTAG acceptance script.
 // Check the packing during every scenario, including actual clock gating.
 always @(negedge clk)if(rst_n)begin
  if(trace[256]!==dut.ll_clock_enable || trace[260:257]!==dut.debug_sleep_state ||
     trace[292:261]!==dut.debug_wake_count || trace[324:293]!==dut.debug_sleep_count ||
     trace[356:325]!==dut.debug_main_clocks || trace[234:203]!==dut.case_id)
   $fatal(1,"ILA trace ABI mismatch");
 end
 reg [31:0] commands[0:524287];reg [31:0] result;integer pc=0,case_id=0;
 integer winner,kind,idx,starts,txs,ends;reg [15:0] seen;reg [31:0] event_head;
 task bus(input bit wr,input [18:0] a,input [31:0] v,input [3:0] b);
  @(negedge clk);host_req=1;host_write=wr;host_addr=a;host_wdata=v;host_be=b;
  do begin @(posedge clk);#1;end while(host_wait);
  if(host_error)$fatal(1,"host error case=%0d addr=%h",case_id,a);
  result=host_rdata;@(negedge clk);host_req=0;@(negedge clk);
 endtask
 initial begin
  $readmemh("board_vectors.mem",commands);
  repeat(4)@(negedge clk);rst_n=1;repeat(16)@(negedge clk);
  while(commands[pc]!=0)begin
   case(commands[pc])
    1:bus(1,commands[pc+1],commands[pc+2],commands[pc+3]);
    2:begin bus(0,commands[pc+1],0,15);if(((result^commands[pc+2])&commands[pc+3])!=0)$fatal(1,"postcheck case=%0d addr=%h got=%h expected=%h mask=%h",case_id,commands[pc+1],result,commands[pc+2],commands[pc+3]);end
    3:repeat(commands[pc+1])@(negedge clk);
    4:begin
     case_id=commands[pc+1];
     do bus(0,'h40008,0,15);while(result[0]);
     if(!result[1]||result[2])begin
      bus(0,'h40018,0,15);$display("failure pc/reason=%h",result);
      bus(0,'h4001c,0,15);$display("actual=%h",result);bus(0,'h40020,0,15);$display("expected=%h",result);
      $fatal(1,"board scenario %0d failed",case_id);
     end
    end
    5:$display("BOARD_SCENARIO_PASS %0d",commands[pc+1]);
    6:begin
     winner=commands[pc+1];seen=0;starts=0;txs=0;ends=0;
     repeat(18)begin
      bus(0,'h24,0,15);event_head=result;kind=result[15:12];idx=result[11:8];
      if(kind==1)begin starts=starts+1;if(idx!=winner)$fatal(1,"wrong priority");end
      else if(kind==6)begin txs=txs+1;if(idx!=winner)$fatal(1,"loser TX");end
      else begin
       if(seen[idx])$fatal(1,"duplicate terminal");seen[idx]=1;ends=ends+1;
       if(idx==winner&&kind!=2)$fatal(1,"winner terminal");
       if(idx!=winner&&(kind!=3||event_head[23:16]!=2))$fatal(1,"conflict reason");
      end
      bus(1,'h110,'h201,15);
     end
     if(starts!=1||txs!=1||ends!=16||seen!=commands[pc+2])$fatal(1,"competition event accounting");
    end
    default:$fatal(1,"bad host command");
   endcase
   pc=pc+4;
  end
  $display("SLE_TEST_PASS: tb_board_suite");$finish;
 end
 initial begin #2000000000;$fatal(1,"suite timeout case=%0d pc=%0d",case_id,pc);end
endmodule
