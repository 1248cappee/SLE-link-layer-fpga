`default_nettype none
// Independent single-bit levels only; not an atomic multi-bit bus transfer.
module simple_synchro #(parameter integer WIDTH=1)(
 input wire clk,rst_n,input wire [WIDTH-1:0] async_in,
 output wire [WIDTH-1:0] sync_out
);
 (* ASYNC_REG="TRUE",SHREG_EXTRACT="NO" *)reg [WIDTH-1:0] stage1,stage2;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin stage1<=0;stage2<=0;end
  else begin stage1<=async_in;stage2<=stage1;end
 assign sync_out=stage2;
endmodule
`default_nettype wire
