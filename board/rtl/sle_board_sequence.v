`default_nettype none
// 1024 x 128-bit microcode. CPU only writes while idle. No RAM reset.
// op0 END;1 WRITE;2 CHECK;3 WAIT cycles;4 POLL;5 WAIT absolute time;
// 6 relative ET publish;7 relative ET time preparation;8 publish at lead fine.
// bit16 expects a bus error. words: op/be, local address, value, mask.
module sle_board_sequence(
 input wire clk,rst_n,start,abort,
 input wire load,input wire [11:0] load_addr,input wire [31:0] load_data,
 input wire [3:0] load_be,input wire [29:0] now_slot,input wire [9:0] now_fine,
 input wire [31:0] main_clocks,
 output reg busy,done,failed,output reg [9:0] pc,output reg [7:0] reason,
 output reg [31:0] actual,expected,output wire req,wr,output wire [17:0] addr,
 output wire [31:0] data,output wire [3:0] be,
 input wire wait_i,input wire [31:0] rdata,input wire error
 ,output reg [63:0] run_cycles
);
 (* ram_style="block" *) reg [127:0] code[0:1023];
 reg [127:0] insn;reg [4:0] state;reg [31:0] left;reg [25:0] watchdog;
 reg [31:0] loop_left;
 reg time_checked;
 reg [29:0] checked_slot;
 reg [9:0] checked_fine;
 reg [31:0] stopped_clocks;
 wire [29:0] checked_delta=now_slot-checked_slot;
 reg [29:0] target_slot;reg [9:0] target_fine,last_fine;reg [17:0] et_address;reg [15:0] flags;
 reg [15:0] block_index;
 wire block_op=state==14;
 wire helper=state==7||state==9||state==11;
 wire outstanding=state==3||helper||block_op||state==16||state==18;
 wire [17:0] block_address=insn[49:32]+{block_index,2'b00};
 wire [29:0] delta_slot=target_slot-now_slot;
 wire [39:0] delta_fine=delta_slot*40'd250+target_fine-now_fine;
 reg load_valid;reg [11:0] load_address;reg [31:0] load_value;reg [3:0] load_bytes;
 integer k;
 always @(posedge clk)begin
  if(!rst_n)load_valid<=0;else load_valid<=load&&!busy;
  load_address<=load_addr;load_value<=load_data;load_bytes<=load_be;
  if(load_valid)for(k=0;k<4;k=k+1)if(load_bytes[k])code[load_address[11:2]][load_address[1:0]*32+k*8+:8]<=load_value[k*8+:8];
  insn<=code[pc];
 end
 assign req=busy&&(state==3||helper||block_op||state==16||state==18);
 assign wr=helper||state==16||state==18||insn[7:0]==1||(block_op&&insn[7:0]==10);
 assign addr=state==16?insn[49:32]:state==18?insn[49:32]+18'd4:block_op?block_address:helper?(et_address+(state==9?18'd4:18'd0)):insn[49:32];
 assign data=state==7?{target_slot[15:0],(flags&16'hffc7)}:
             state==9?{6'd0,target_fine,2'd0,target_slot[29:16]}:
             state==11?{16'd0,flags[15:6],3'd1,flags[2:0]}:
             state==16?{2'd0,target_slot}:state==18?{22'd0,target_fine}:
             block_op?(insn[95:64]^{14'd0,block_address}):insn[95:64];
 assign be=block_op?4'd15:helper?(state==11?4'd3:4'd15):insn[11:8];
 task fail;input [7:0] why;begin failed<=1;done<=1;busy<=0;reason<=why;end endtask
 task advance;begin watchdog<=0;if(pc==1023)fail(8'd6);else begin pc<=pc+1'b1;state<=0;end end endtask
 always @(posedge clk)begin
  if(!rst_n)begin busy<=0;done<=0;failed<=0;pc<=0;reason<=0;actual<=0;expected<=0;state<=0;left<=0;watchdog<=0;target_slot<=0;target_fine<=0;last_fine<=0;et_address<=0;flags<=0;block_index<=0;loop_left<=0;run_cycles<=0;time_checked<=0;checked_slot<=0;checked_fine<=0;stopped_clocks<=0;end
  else if(!busy)begin
   if(start)begin busy<=1;done<=0;failed<=0;reason<=0;pc<=0;state<=0;watchdog<=0;loop_left<=0;run_cycles<=0;time_checked<=0;end
  end else begin
   run_cycles<=run_cycles+1'b1;
   if(!(&watchdog))watchdog<=watchdog+1'b1;
   if(abort)begin
    // An accepted bus operation must finish and withdraw before releasing owner.
    if(!outstanding||!wait_i)fail(8'd5);
   end else if(&watchdog)begin if(!outstanding||!wait_i)fail(8'd4);end
   else case(state)
    0:state<=1;
    1:state<=2;
    2:case(insn[7:0])
     0:begin done<=1;busy<=0;end
     1,2,4:state<=3;
     3:begin left<=insn[95:64];state<=4;end
     5:state<=5;
     6,7:begin target_slot<=now_slot+insn[93:64];target_fine<=insn[121:112];et_address<=insn[49:32];flags<=insn[111:96];state<=7;end
     8:begin state<=12;last_fine<=now_fine;end
     9:begin et_address<=insn[49:32];flags<=insn[111:96];state<=7;end
     10,11:if(insn[127:96]==0||insn[127:96]>32768||insn[63:32]<32'h20000||
       insn[63:32]+(insn[127:96]<<2)>32'h40000||insn[33:32]!=0)fail(8'd7);
       else begin block_index<=0;state<=14;end
     12:begin
      watchdog<=0;
      if(insn[63:32]>1023||insn[95:64]==0)fail(8'd7);
      else if(loop_left==1)begin loop_left<=0;advance;end
      else if(loop_left==0&&insn[95:64]==1)advance;
      else begin loop_left<=loop_left==0?insn[95:64]-1'b1:loop_left-1'b1;pc<=insn[41:32];state<=0;end
     end
     13:state<=16;
     14:begin
      watchdog<=0;
      if(insn[63:32]>1023)fail(8'd7);
      else if(run_cycles<insn[127:64])begin pc<=insn[41:32];state<=0;end
      else advance;
     end
     15:begin
      if(now_fine>249 || (time_checked&&(checked_delta[29] ||
         (checked_delta==0&&(now_fine<checked_fine||(insn[64]&&now_fine==checked_fine))))))begin
       actual<={2'd0,now_slot};expected<={2'd0,checked_slot};fail(8'd8);
      end else begin time_checked<=1;checked_slot<=now_slot;checked_fine<=now_fine;advance;end
     end
     16:if(insn[64])begin
       if(main_clocks!=stopped_clocks)begin actual<=main_clocks;expected<=stopped_clocks;fail(8'd9);end
       else advance;
      end else begin stopped_clocks<=main_clocks;advance;end
     17:if(main_clocks==stopped_clocks)fail(8'd10);else advance;
     default:fail(8'd1);
    endcase
    3:if(!wait_i)begin
     actual<=rdata;expected<=insn[95:64];
     if(error!=insn[16])fail(8'd2);
     else if(insn[7:0]==2&&((rdata^insn[95:64])&insn[127:96])!=0)fail(8'd3);
     else if(insn[7:0]==4&&((rdata^insn[95:64])&insn[127:96])!=0)state<=6;
     else advance;
    end
    4:if(left==0)advance;else left<=left-1'b1;
    5:if(now_slot==insn[93:64]&&now_fine==insn[105:96])advance;
    6:state<=3;
    7:if(!wait_i)begin if(error)fail(8'd2);else state<=8;end
    8:state<=9;
    9:if(!wait_i)begin if(error)fail(8'd2);else state<=10;end
    10:if(insn[7:0]==6||insn[7:0]==9)state<=11;else advance;
    11:if(!wait_i)begin if(error)fail(8'd2);else advance;end
    12:begin
     last_fine<=now_fine;
     // Start at a fine boundary, then account for the fixed idle XBAR/EM
     // pipeline. Regression checks the actual scheduler commit timestamp.
     if(now_fine!=last_fine&&delta_fine==insn[95:64]+1)begin left<=4;state<=13;end
    end
    13:if(left==0)state<=11;else left<=left-1'b1;
    14:if(!wait_i)begin
     actual<=rdata;expected<=data;
     if(error)fail(8'd2);
     else if(insn[7:0]==11&&rdata!=data)fail(8'd3);
     else if({16'd0,block_index}+1==insn[127:96])advance;
     else begin block_index<=block_index+1'b1;state<=15;end
    end
    15:state<=14;
    16:if(!wait_i)begin if(error)fail(8'd2);else state<=17;end
    17:state<=18;
    18:if(!wait_i)begin if(error)fail(8'd2);else state<=19;end
    19:advance;
    default:fail(8'd1);
   endcase
  end
 end
endmodule
`default_nettype wire
