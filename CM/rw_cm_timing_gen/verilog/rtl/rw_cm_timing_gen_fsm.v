`default_nettype none
// Always-on sleep controller. The P101 profile uses an internally generated
// 32768-Hz reference CE; the 20-MHz AON phase supplies the explicitly reported
// quantization correction. This does not model an independent crystal.
module rw_cm_timing_gen_fsm #(parameter integer CLK_HZ=20000000,LP_HZ=32768)(
 input wire clk,rst_n,req,write,
 input wire [11:0] addr,
 input wire [31:0] wdata,
 input wire [3:0] be,
 output reg ack,error,
 output reg [31:0] rdata,
 input wire safe_to_sleep,external_wake,restore_ack,
 input wire [29:0] live_slot,
 input wire [9:0] live_fine,live_day,
 input wire live_day_valid,
 input wire [31:0] live_phase,
 input wire [2:0] armed,
 input wire [89:0] target_slots,
 input wire [29:0] target_fines,
 output wire clock_enable,block_core,hold_time,restore,
 output wire [29:0] restore_slot,
 output wire [9:0] restore_fine,restore_day,
 output wire [31:0] restore_phase,
 output wire restore_day_valid,
 output reg wake_event,
 output wire [3:0] sleep_state,
 output reg [31:0] sleep_count,wake_count,lp_edges,last_correction,
 output reg [7:0] reason
);
 localparam DIV=CLK_HZ/2000000;
 reg [3:0] state;
 reg enabled,held,software_wake,pending_wake;
 reg [31:0] duration,margin,remaining,delay_count,lp_accumulator;
 reg [31:0] shadow_phase,elapsed_fines,lp_fines,lp_remainder;
 reg [29:0] shadow_slot;
 reg [9:0] shadow_fine,shadow_day;
 reg shadow_day_valid;
 (* ASYNC_REG="TRUE" *) reg [1:0] wake_sync,ack_sync;
 wire [29:0] next_slot;
 wire [9:0] next_fine,next_day;
 wire next_day_valid;
 wire [31:0] next_phase;
 reg [31:0] chosen_duration,candidate,delta,lp_total;
 integer j;
 assign sleep_state=state;
 assign block_core=state!=0;
 assign hold_time=state>=2&&state<=5;
 assign clock_enable=state!=3;
 assign restore=state==5;
 assign restore_slot=next_slot;assign restore_fine=next_fine;
 assign restore_phase=next_phase;assign restore_day=next_day;
 assign restore_day_valid=next_day_valid;
 rw_cm_timing_gen_resync #(.DIV(DIV)) correction(
  .slot(state==1?live_slot:shadow_slot),.fine(state==1?live_fine:shadow_fine),
  .phase(state==1?live_phase:shadow_phase),.day_count(state==1?live_day:shadow_day),
  .day_valid(state==1?live_day_valid:shadow_day_valid),.next_slot(next_slot),.next_fine(next_fine),
  .next_phase(next_phase),.next_day(next_day),.next_day_valid(next_day_valid));
 always @* begin
  chosen_duration=duration;
  candidate=0;delta=0;
  for(j=0;j<3;j=j+1)if(armed[j])begin
   delta=target_slots[j*30+:30]-live_slot;
   if(delta[29] || (delta==0&&target_fines[j*10+:10]<=live_fine))chosen_duration=0;
   else if(delta<32'h01000000)begin
    candidate=delta*250+target_fines[j*10+:10]-live_fine;
    if(candidate<chosen_duration)chosen_duration=candidate;
   end
  end
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=0;enabled<=0;held<=0;ack<=0;error<=0;rdata<=0;software_wake<=0;pending_wake<=0;
   duration<=0;margin<=500;remaining<=0;delay_count<=0;reason<=0;
   shadow_slot<=0;shadow_fine<=0;shadow_phase<=0;shadow_day<=1;shadow_day_valid<=1;
   wake_sync<=0;ack_sync<=0;wake_event<=0;sleep_count<=0;wake_count<=0;
   lp_accumulator<=0;lp_edges<=0;elapsed_fines<=0;lp_fines<=0;lp_remainder<=0;last_correction<=0;
  end else begin
   ack<=0;error<=0;wake_event<=0;
   if(state==0)begin software_wake<=0;pending_wake<=0;end
   else if(wake_sync[1])pending_wake<=1;
   wake_sync<={wake_sync[0],external_wake};ack_sync<={ack_sync[0],restore_ack};
   if(!req)held<=0;
   if(req&&!held)begin
    held<=1;ack<=1;rdata<=0;
    if(addr[1:0]!=0)error<=1;
    else if(!write)case(addr)
     12'h030:rdata<={31'd0,enabled};12'h034:rdata<=duration;
     12'h038,12'h508:rdata<={20'd0,reason,state};
     12'h500:rdata<=32'h534c434d;12'h504:rdata<=32'h00010001;
     12'h50c:rdata<=margin;12'h510:rdata<=sleep_count;12'h514:rdata<=wake_count;
     12'h518:rdata<=lp_edges;12'h51c:rdata<=last_correction;
     12'h520:rdata<=32'h0000001f; // five scheduling grids, no HMAC capability
     12'h524:rdata<=remaining;12'h528:rdata<=elapsed_fines;
     default:error<=1;
    endcase
    else case(addr)
     12'h030:if(!be[0]||wdata[31:3]!=0)error<=1;
      else if(wdata[2])software_wake<=1;
      else if(state!=0)error<=1;
      else begin
       enabled<=wdata[0];
       if(wdata[1])begin
        if(!wdata[0]||!safe_to_sleep||wake_sync[1])begin error<=1;reason<=1;end
        else if(chosen_duration<=margin+4)begin error<=1;reason<=2;end
        else begin state<=1;remaining<=chosen_duration-margin;reason<=0;end
       end
      end
     12'h034:if(state!=0||be!=15)error<=1;else duration<=wdata;
     12'h50c:if(state!=0||be!=15||wdata<500)error<=1;else margin<=wdata;
     default:error<=1;
    endcase
   end
   case(state)
    0:begin
     shadow_slot<=live_slot;shadow_fine<=live_fine;shadow_phase<=live_phase;
     shadow_day<=live_day;shadow_day_valid<=live_day_valid;
    end
    1:if(!req)begin
     if(!safe_to_sleep)begin reason<=1;state<=0;end
     else begin
      shadow_slot<=next_slot;shadow_fine<=next_fine;shadow_phase<=next_phase;
      shadow_day<=next_day;shadow_day_valid<=next_day_valid;
      elapsed_fines<=0;lp_fines<=0;lp_remainder<=0;lp_edges<=0;lp_accumulator<=0;
      state<=2;delay_count<=0;
     end
    end
    2:begin
     if(delay_count==3)begin state<=3;sleep_count<=sleep_count+1'b1;end
     else delay_count<=delay_count+1'b1;
    end
    3:if(wake_sync[1]||pending_wake||software_wake||remaining==0)begin
     reason<=(wake_sync[1]||pending_wake)?8'd4:(software_wake?8'd8:8'd2);state<=4;delay_count<=0;
    end
    4:if(delay_count==7)state<=5;else delay_count<=delay_count+1'b1;
    5:if(ack_sync[1])begin state<=6;delay_count<=0;last_correction<=elapsed_fines-lp_fines;end
    6:if(!ack_sync[1]&&delay_count>=4)begin state<=0;wake_event<=1;wake_count<=wake_count+1'b1;end
      else delay_count<=delay_count+1'b1;
    default:state<=0;
   endcase
   if(state>=2)begin
    shadow_slot<=next_slot;shadow_fine<=next_fine;shadow_phase<=next_phase;
    shadow_day<=next_day;shadow_day_valid<=next_day_valid;
    if(shadow_phase==DIV-1)begin
     elapsed_fines<=elapsed_fines+1'b1;
     if(remaining!=0)remaining<=remaining-1'b1;
    end
    if(lp_accumulator>=CLK_HZ-LP_HZ)begin
     lp_accumulator<=lp_accumulator+LP_HZ-CLK_HZ;lp_edges<=lp_edges+1'b1;
     lp_total=lp_remainder+2000000;
     lp_fines<=lp_fines+lp_total/LP_HZ;lp_remainder<=lp_total%LP_HZ;
    end else lp_accumulator<=lp_accumulator+LP_HZ;
   end
  end
 end
endmodule
`default_nettype wire
