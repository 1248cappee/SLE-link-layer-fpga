`default_nettype none
// Bundled-data CDC: data remains stable from accepted source pulse until ACK.
// The destination consumes the data on dst_pulse; there is one outstanding item.
module pulse_to_pulse_synchro #(parameter integer WIDTH=40)(
 input wire src_clk,src_rst_n,dst_clk,dst_rst_n,src_pulse,
 input wire [WIDTH-1:0] src_data,
 output wire src_ready,src_overflow,
 output reg dst_pulse,
 output reg [WIDTH-1:0] dst_data
);
 reg [WIDTH-1:0] held_data;
 wire pulse;
 pulse_synchro crossing(.src_clk(src_clk),.src_rst_n(src_rst_n),.dst_clk(dst_clk),.dst_rst_n(dst_rst_n),
  .src_pulse(src_pulse),.src_ready(src_ready),.src_overflow(src_overflow),.dst_pulse(pulse));
 always @(posedge src_clk or negedge src_rst_n)
  if(!src_rst_n)held_data<=0;else if(src_pulse&&src_ready)held_data<=src_data;
 always @(posedge dst_clk or negedge dst_rst_n)
  if(!dst_rst_n)begin dst_data<=0;dst_pulse<=0;end
  else begin dst_pulse<=pulse;if(pulse)dst_data<=held_data;end
endmodule
`default_nettype wire
