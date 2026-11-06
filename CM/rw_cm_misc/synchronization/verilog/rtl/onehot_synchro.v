`default_nettype none
module onehot_synchro #(parameter integer WIDTH=4)(
 input wire clk,rst_n,input wire [WIDTH-1:0] async_in,
 output wire [WIDTH-1:0] sync_out,output wire illegal
);
 wire [WIDTH-1:0] sampled;
 simple_synchro #(.WIDTH(WIDTH)) s(.clk(clk),.rst_n(rst_n),.async_in(async_in),.sync_out(sampled));
 assign illegal=(sampled&(sampled-1'b1))!=0;
 assign sync_out=illegal?{WIDTH{1'b0}}:sampled;
endmodule
`default_nettype wire
