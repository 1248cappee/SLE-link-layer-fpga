`include "sle_defs.vh"
`default_nettype none
module rw_cm_activity_scheduler #(parameter integer EM_BYTES=131072)(
 input wire clk,rst_n,enable,freeze,
 input wire [13:0] etptr,
 input wire [29:0] now_slot,
 input wire [9:0] now_fine,
 input wire [2047:0] cm_banks,
 input wire commit,
 input wire [3:0] commit_index,
 input wire [29:0] commit_slot,
 input wire [9:0] commit_fine,
 input wire cancel,
 input wire [3:0] cancel_index,
 input wire terminal_pop,
 input wire [3:0] pop_index,
 input wire clear_start,
 output reg clear_done,
 output reg [15:0] owned,
 output wire idle,
 output reg em_req,em_write,
 output reg [16:0] em_addr,
 output reg [31:0] em_wdata,
 output reg [3:0] em_be,
 input wire em_ack,em_fault,
 input wire [31:0] em_rdata,
 output reg job_valid,
 input wire job_ready,
 output reg [3:0] job_index,
 output reg [13:0] job_csptr,
 output reg [2:0] job_mode,
 output reg [4:0] job_priority,
 output reg [29:0] job_slot,
 output reg [9:0] job_fine,
 output wire engine_cancel,engine_requeue,
 input wire engine_idle,engine_running,engine_started,engine_done,engine_abandoned,
 input wire [29:0] actual_start_slot,
 input wire [9:0] actual_start_fine,
 input wire [2:0] engine_status,
 input wire [7:0] engine_reason,
 output reg start_ack,
 output reg event_valid,
 input wire event_ready,
 output reg [71:0] event_data,
 output reg [4:0] error_set
);
 localparam S_IDLE=0,S_READ=1,S_READ_WAIT=2,S_CHECK=3,S_WRITE=4,S_WRITE_WAIT=5,S_EVENT=6,S_JOB=7,S_CLEAR=8,S_CLEAR_WAIT=9;
 reg [3:0] state;
 reg [15:0] pending,valid,retired,cancelled;
 reg [29:0] submitted_slot[0:15],target_slot[0:15];
 reg [9:0] submitted_fine[0:15],target_fine[0:15];
 reg [31:0] et0[0:15];
 reg [13:0] cs[0:15];
 reg [2:0] mode[0:15];
 reg [4:0] priority[0:15];
 reg [31:0] fetched0,fetched1,fetched2;
 reg [3:0] scan,active_index,write_index,clear_index;
 reg [1:0] read_word;
 reg assigned,start_pending,done_pending;
 reg [29:0] saved_start_slot;
 reg [9:0] saved_start_fine;
 reg [2:0] saved_done_status,write_status;
 reg [7:0] saved_done_reason,write_reason;
 reg [3:0] write_type;
 reg [29:0] stamp_slot;
 reg [9:0] stamp_fine;
 reg [3:0] best,pending_index,expired;
 reg best_found,pending_found,expired_found;
 reg [48:0] winner_key[0:31];
 reg winner_valid[0:31];
 reg [29:0] delta,delta2;
 reg [38:0] lead;
 integer i;
 wire [127:0] scan_config=cm_banks[{scan,7'b0}+:128];
 wire grid_legal;
 sle_schedule_grid grid(.selection(scan_config[2:0]),.enabled(scan_config[3]===1'b1),
  .target_slot({fetched1[13:0],fetched0[31:16]}),.target_fine(fetched1[25:16]),
  .origin_slot(scan_config[32+:30]),.origin_fine(scan_config[64+:10]),.legal(grid_legal));
 function before_time;
  input [29:0] a,b;
  input [9:0] af,bf;
  reg [29:0] d;
  begin d=a-b;before_time=(d==0)?af<bf:d[29];end
 endfunction
 always @* begin
  best=0;best_found=0;pending_index=0;pending_found=0;expired=0;expired_found=0;
  winner_key[0]=0;winner_valid[0]=0;
  for(i=0;i<16;i=i+1) begin
   winner_key[16+i]={target_slot[i],target_fine[i],priority[i],i[3:0]};
   winner_valid[16+i]=valid[i]&&!retired[i]&&!(assigned&&i==active_index);
   if(pending[i]&&!pending_found) begin pending_index=i;pending_found=1;end
   if(valid[i]&&!retired[i]&&!(assigned&&i==active_index)) begin
    if(!before_time(now_slot,target_slot[i],now_fine,target_fine[i]) && !expired_found) begin expired=i;expired_found=1;end
   end
  end
  // Four-level tournament, not a serial chain of sixteen 30-bit compares.
  for(i=15;i>=1;i=i-1) begin
   winner_valid[i]=winner_valid[2*i]||winner_valid[2*i+1];
   if(winner_valid[2*i] && (!winner_valid[2*i+1] ||
      before_time(winner_key[2*i][48:19],winner_key[2*i+1][48:19],winner_key[2*i][18:9],winner_key[2*i+1][18:9]) ||
      (winner_key[2*i][48:9]==winner_key[2*i+1][48:9] &&
       (winner_key[2*i][8:4]>winner_key[2*i+1][8:4] ||
        (winner_key[2*i][8:4]==winner_key[2*i+1][8:4]&&winner_key[2*i][3:0]<winner_key[2*i+1][3:0])))))
    winner_key[i]=winner_key[2*i];
   else winner_key[i]=winner_key[2*i+1];
  end
  best=winner_key[1][3:0];best_found=winner_valid[1];
 end
 assign idle=(owned==0 && !assigned && state==S_IDLE && !job_valid);
 assign engine_cancel=freeze || (assigned && cancelled[active_index]);
 assign engine_requeue=assigned && !engine_running && best_found && !freeze &&
  (before_time(target_slot[best],job_slot,target_fine[best],job_fine) ||
   (target_slot[best]==job_slot && target_fine[best]==job_fine &&
    (priority[best]>priority[active_index] || (priority[best]==priority[active_index]&&best<active_index))));
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   state<=S_IDLE;pending<=0;valid<=0;retired<=0;cancelled<=0;owned<=0;
   assigned<=0;active_index<=0;scan<=0;read_word<=0;fetched0<=0;fetched1<=0;fetched2<=0;
   em_req<=0;em_write<=0;em_addr<=0;em_wdata<=0;em_be<=0;
   job_valid<=0;job_index<=0;job_csptr<=0;job_mode<=0;job_priority<=0;job_slot<=0;job_fine<=0;
   start_pending<=0;done_pending<=0;start_ack<=0;event_valid<=0;event_data<=0;error_set<=0;
   saved_start_slot<=0;saved_start_fine<=0;saved_done_status<=0;saved_done_reason<=0;
   write_index<=0;write_status<=0;write_reason<=0;write_type<=0;stamp_slot<=0;stamp_fine<=0;
   clear_done<=0;clear_index<=0;
   for(i=0;i<16;i=i+1) begin
    submitted_slot[i]<=0;submitted_fine[i]<=0;target_slot[i]<=0;target_fine[i]<=0;
    et0[i]<=0;cs[i]<=0;mode[i]<=0;priority[i]<=0;
   end
  end else begin
   error_set<=0;start_ack<=0;clear_done<=0;
   if(terminal_pop) begin owned[pop_index]<=0;retired[pop_index]<=0;cancelled[pop_index]<=0;end
   if(commit) begin
    if(owned[commit_index] || etptr==0 || freeze) error_set[4]<=1;
    else begin
     pending[commit_index]<=1;owned[commit_index]<=1;
     submitted_slot[commit_index]<=commit_slot;submitted_fine[commit_index]<=commit_fine;
    end
   end
   if(cancel && owned[cancel_index] && !retired[cancel_index]) cancelled[cancel_index]<=1;
   if(engine_started) begin start_pending<=1;saved_start_slot<=actual_start_slot;saved_start_fine<=actual_start_fine;end
   if(engine_done) begin done_pending<=1;saved_done_status<=engine_status;saved_done_reason<=engine_reason;end
   if(engine_abandoned) assigned<=0;
   case(state)
    S_IDLE: begin
     if(clear_start && engine_idle) begin clear_index<=0;state<=S_CLEAR;end
     else if(start_pending) begin
      start_pending<=0;write_index<=active_index;write_status<=`SLE_RUNNING;
      write_type<=`SLE_EV_START;write_reason<=0;stamp_slot<=saved_start_slot;stamp_fine<=saved_start_fine;state<=S_WRITE;
     end else if(done_pending) begin
      done_pending<=0;write_index<=active_index;write_status<=saved_done_status;write_reason<=saved_done_reason;
      write_type<=saved_done_status==`SLE_CANCELLED?`SLE_EV_CANCEL:(saved_done_status==`SLE_ERROR?`SLE_EV_ERROR:(saved_done_status==`SLE_SKIPPED?`SLE_EV_SKIP:`SLE_EV_END));
      stamp_slot<=now_slot;stamp_fine<=now_fine;state<=S_WRITE;
     end else if((enable||cancelled[pending_index]) && !freeze && pending_found) begin
      scan<=pending_index;pending[pending_index]<=0;read_word<=0;state<=S_READ;
     end else if(!freeze && expired_found && (assigned || !engine_idle)) begin
      write_index<=expired;write_status<=`SLE_SKIPPED;write_type<=`SLE_EV_SKIP;write_reason<=`SLE_CONFLICT;
      stamp_slot<=now_slot;stamp_fine<=now_fine;state<=S_WRITE;
     end else if(!freeze && enable && engine_idle && !assigned && best_found) begin
      job_index<=best;job_csptr<=cs[best];job_mode<=mode[best];job_slot<=target_slot[best];job_fine<=target_fine[best];
      job_priority<=priority[best];
      job_valid<=1;state<=S_JOB;
     end
    end
    S_JOB: if(job_valid && job_ready) begin
     assigned<=1;active_index<=job_index;job_valid<=0;state<=S_IDLE;
    end
    S_READ: begin
     em_req<=1;em_write<=0;em_be<=4'hf;em_addr<=({3'd0,etptr}<<1)+{9'd0,scan,4'd0}+{13'd0,read_word,2'd0};state<=S_READ_WAIT;
    end
    S_READ_WAIT: if(em_ack) begin
     em_req<=0;
     if(em_fault) begin error_set[3]<=1;valid[scan]<=0;state<=S_IDLE;end
     else begin
      case(read_word) 0:fetched0<=em_rdata;1:fetched1<=em_rdata;2:fetched2<=em_rdata;default:begin end endcase
      if(read_word==2) state<=S_CHECK;
      else begin read_word<=read_word+1'b1;state<=S_READ;end
     end
    end
    S_CHECK: begin
     et0[scan]<=fetched0;mode[scan]<=fetched0[2:0];priority[scan]<=fetched0[15:11];cs[scan]<=fetched2[13:0];
     target_slot[scan]<={fetched1[13:0],fetched0[31:16]};target_fine[scan]<=fetched1[25:16];
     write_index<=scan;stamp_slot<=now_slot;stamp_fine<=now_fine;
     delta={fetched1[13:0],fetched0[31:16]}-submitted_slot[scan];
     lead={9'd0,delta}*39'd250+{29'd0,fetched1[25:16]}-{29'd0,submitted_fine[scan]};
     if(fetched0[5:3]!=`SLE_READY || fetched0[2:0]>3 || fetched2[13:0]==0 ||
        (({3'd0,fetched2[13:0]}<<1)+146)>EM_BYTES || (({3'd0,fetched2[13:0]}<<1)+146)>32768 ||
        fetched1[31:26]!=0 || fetched1[15:14]!=0 || fetched2[15:14]!=0) begin
      write_status<=`SLE_ERROR;write_type<=`SLE_EV_ERROR;write_reason<=`SLE_BAD_DESC;error_set[0]<=1;
     end else if(fetched1[25:16]>249 || !grid_legal) begin
      write_status<=`SLE_ERROR;write_type<=`SLE_EV_ERROR;write_reason<=`SLE_BAD_DESC;error_set[1]<=1;
     end else if(cancelled[scan]) begin write_status<=`SLE_CANCELLED;write_type<=`SLE_EV_CANCEL;write_reason<=`SLE_SW_CANCEL;end
     else if(delta[29] || lead<500 || lead[38]) begin
      write_status<=`SLE_SKIPPED;write_type<=`SLE_EV_SKIP;write_reason<=`SLE_LATE;
     end else begin write_status<=`SLE_FETCHED;write_type<=0;write_reason<=0;valid[scan]<=1;end
     state<=S_WRITE;
    end
    S_WRITE: begin
     em_req<=1;em_write<=1;em_be<=4'b0011;
     em_addr<=({3'd0,etptr}<<1)+{9'd0,write_index,4'd0};
     em_wdata<={et0[write_index][31:6],write_status,et0[write_index][2:0]};state<=S_WRITE_WAIT;
    end
    S_WRITE_WAIT: if(em_ack) begin
     em_req<=0;
     if(em_fault) begin error_set[3]<=1;state<=S_IDLE;end
     else if(write_type!=0) begin
      event_data<={2'd0,14'd0,stamp_fine,stamp_slot,write_reason,write_type,write_index};event_valid<=1;state<=S_EVENT;
      if(write_status>=`SLE_DONE) begin valid[write_index]<=0;retired[write_index]<=1;end
     end else state<=S_IDLE;
    end
    S_EVENT: if(event_ready) begin
     event_valid<=0;
     if(write_type==`SLE_EV_START) start_ack<=1;
     else if(assigned && write_index==active_index) assigned<=0;
     state<=S_IDLE;
    end
    S_CLEAR: begin
     if(etptr==0) begin clear_done<=1;state<=S_IDLE;end
     else begin
      em_req<=1;em_write<=1;em_be<=4'b0011;em_wdata<=0;
      em_addr<=({3'd0,etptr}<<1)+{9'd0,clear_index,4'd0};state<=S_CLEAR_WAIT;
     end
    end
    S_CLEAR_WAIT: if(em_ack) begin
     em_req<=0;
     if(em_fault) begin error_set[3]<=1;state<=S_IDLE;end
     else if(clear_index==15) begin clear_done<=1;state<=S_IDLE;end
     else begin clear_index<=clear_index+1'b1;state<=S_CLEAR;end
    end
    default:state<=S_IDLE;
   endcase
   // Cancellation of a fetched task must not wait for its target time.
   if(state==S_IDLE && !start_pending && !done_pending && !clear_start && !freeze) begin
    for(i=15;i>=0;i=i-1) if(valid[i]&&cancelled[i]&&!(assigned&&active_index==i)) begin
     write_index<=i;write_status<=`SLE_CANCELLED;write_type<=`SLE_EV_CANCEL;write_reason<=`SLE_SW_CANCEL;
     stamp_slot<=now_slot;stamp_fine<=now_fine;job_valid<=0;state<=S_WRITE;
    end
   end
  end
 end
endmodule
`default_nettype wire
