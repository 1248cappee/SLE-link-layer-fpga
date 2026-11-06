`default_nettype none
module rw_cm_timing_gen #(parameter integer CLK_HZ=20000000)(
 input wire clk, rst_n,
 input wire load_time, snap, arm_we,
 input wire restore,hold_time,
 input wire [29:0] restore_slot,
 input wire [9:0] restore_fine,restore_day,
 input wire [31:0] restore_phase,
 input wire restore_day_valid,
 input wire [29:0] load_slot,
 input wire [9:0] load_fine,
 input wire [2:0] arm_data,
 input wire [89:0] target_slots,
 input wire [29:0] target_fines,
 output reg [29:0] slot,
 output reg [9:0] fine,
 output reg [29:0] snap_slot,
 output reg [9:0] snap_fine,
 output reg tick_fine, tick_slot,
 output reg [2:0] armed, fired,
 output wire [31:0] phase,
 output reg [9:0] day_count,
 output reg day_valid,
 output reg [15:0] time_generation
);
 localparam integer DIV=CLK_HZ/2000000;
 reg [31:0] divider;
 assign phase=divider;
 integer j;
 reg [29:0] delta;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   slot<=0; fine<=0; snap_slot<=0; snap_fine<=0; divider<=0;
   tick_fine<=0; tick_slot<=0; armed<=0; fired<=0;
   day_count<=1;day_valid<=1;time_generation<=0;
  end else begin
   tick_fine<=0; tick_slot<=0; fired<=0;
   if(restore===1'b1) begin slot<=restore_slot;fine<=restore_fine;divider<=restore_phase;
    day_count<=restore_day;day_valid<=restore_day_valid;end
   else if(load_time) begin slot<=load_slot; fine<=load_fine; divider<=0;
    day_count<=load_slot[29]?10'd0:10'd1;
    if(&time_generation)day_valid<=0;
    else begin day_valid<=1;time_generation<=time_generation+1'b1;end
   end
   else if(hold_time===1'b1)begin end
   else if(divider==DIV-1) begin
    divider<=0; tick_fine<=1;
    if(fine==249) begin fine<=0; slot<=slot+1'b1; tick_slot<=1;
     if(&slot)begin if(&day_count)day_valid<=0;else day_count<=day_count+1'b1;end
    end
    else fine<=fine+1'b1;
   end else divider<=divider+1'b1;
   if(snap) begin snap_slot<=slot; snap_fine<=fine; end
   if(arm_we) armed<=arm_data;
   for(j=0;j<3;j=j+1) begin
    delta=slot-target_slots[j*30+:30];
    if(armed[j] && !arm_we && !load_time && !(restore===1'b1) && !(hold_time===1'b1) &&
       ((!delta[29] && delta!=0) || (delta==0 && fine>=target_fines[j*10+:10]))) begin
     fired[j]<=1; armed[j]<=0;
    end
   end
  end
 end
 // synthesis translate_off
 initial if(CLK_HZ<2000000 || CLK_HZ%2000000!=0) $fatal(1,"CLK_HZ must be an integer multiple of 2 MHz");
 // synthesis translate_on
endmodule
`default_nettype wire
