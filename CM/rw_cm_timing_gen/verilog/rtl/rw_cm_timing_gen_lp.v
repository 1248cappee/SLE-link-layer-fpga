`default_nettype none
// Rational low-power time keeper. The remainder is retained, so 32.768 kHz
// does not accumulate integer-rounding drift in the 2 MHz time domain.
module rw_cm_timing_gen_lp #(parameter integer LP_HZ=32768)(
 input wire low_power_clk,low_power_nrst,load,enable,
 input wire [29:0] load_slot,
 input wire [9:0] load_fine,
 output reg [29:0] slot,
 output reg [9:0] fine
);
 reg [31:0] remainder,total,ticks,fine_total;
 always @(posedge low_power_clk or negedge low_power_nrst) begin
  if(!low_power_nrst) begin slot<=0;fine<=0;remainder<=0;end
  else if(load) begin slot<=load_slot;fine<=load_fine;remainder<=0;end
  else if(enable) begin
   total=remainder+2000000;ticks=total/LP_HZ;remainder<=total%LP_HZ;
   fine_total=fine+ticks;fine<=fine_total%250;slot<=slot+fine_total/250;
  end
 end
endmodule
`default_nettype wire
