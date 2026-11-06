`default_nettype none
// One AON-cycle phase advance, including base-slot and security-day carry.
module rw_cm_timing_gen_resync #(parameter integer DIV=10)(
 input wire [29:0] slot,
 input wire [9:0] fine,day_count,
 input wire [31:0] phase,
 input wire day_valid,
 output reg [29:0] next_slot,
 output reg [9:0] next_fine,next_day,
 output reg [31:0] next_phase,
 output reg next_day_valid
);
 always @* begin
  next_slot=slot;next_fine=fine;next_day=day_count;next_phase=phase;next_day_valid=day_valid;
  if(phase==DIV-1)begin
   next_phase=0;
   if(fine==249)begin
    next_fine=0;next_slot=slot+1'b1;
    if(&slot)begin if(&day_count)next_day_valid=0;else next_day=day_count+1'b1;end
   end else next_fine=fine+1'b1;
  end else next_phase=phase+1'b1;
 end
endmodule
`default_nettype wire
