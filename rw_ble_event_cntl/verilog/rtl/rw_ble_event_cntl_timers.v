`default_nettype none
module rw_ble_event_cntl_timers(
 input wire clk,rst_n,start,tick,stop,
 input wire [15:0] min_time,max_time,
 output reg [31:0] elapsed,
 output wire minimum_met,maximum_met,
 output reg active
);
 reg [15:0] minimum,maximum;
 assign minimum_met=elapsed>=minimum;
 assign maximum_met=active&&elapsed>=maximum;
 always @(posedge clk or negedge rst_n)
  if(!rst_n) begin elapsed<=0;minimum<=0;maximum<=0;active<=0;end
  else if(start) begin elapsed<=0;minimum<=min_time;maximum<=max_time;active<=1;end
  else if(stop) active<=0;
  else if(active&&tick&&elapsed!=32'hffffffff) elapsed<=elapsed+1'b1;
endmodule
`default_nettype wire
