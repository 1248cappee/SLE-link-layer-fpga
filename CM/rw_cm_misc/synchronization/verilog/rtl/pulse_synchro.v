`default_nettype none
// Both domains must participate in a common reset/flush epoch. Source must
// obey ready. Backpressure violations are reported, never silently accepted.
module pulse_synchro(
 input wire src_clk,src_rst_n,dst_clk,dst_rst_n,src_pulse,
 output wire src_ready,src_overflow,dst_pulse
);
 wire request,ack;
 pulse_synchro_src_domain s(.clk(src_clk),.rst_n(src_rst_n),.pulse(src_pulse),.ack_async(ack),
  .request(request),.overflow(src_overflow),.ready(src_ready));
 pulse_synchro_dst_domain d(.clk(dst_clk),.rst_n(dst_rst_n),.request_async(request),.pulse(dst_pulse),.ack(ack));
endmodule
`default_nettype wire
