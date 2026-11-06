`default_nettype none
module dual_edges_synchro(input wire clk,rst_n,async_in,output wire rise,fall,level);
 simple_synchro sync_level(.clk(clk),.rst_n(rst_n),.async_in(async_in),.sync_out(level));
 rising_edge_detector r(.clk(clk),.rst_n(rst_n),.level(level),.pulse(rise));
 falling_edge_detector f(.clk(clk),.rst_n(rst_n),.level(level),.pulse(fall));
endmodule
`default_nettype wire
