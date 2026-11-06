`default_nettype none
// External asynchronous assertion, synchronous request/hold, and two-clock
// release. Only a registered Q drives downstream asynchronous reset pins.
module rw_cm_reset_sync(
 input wire clk,async_n,hold,
 output wire reset_n
);
 (* ASYNC_REG="TRUE",SHREG_EXTRACT="NO" *) reg [1:0] release_pipe;
 always @(posedge clk or negedge async_n)
  if(!async_n)release_pipe<=0;
  else if(hold)release_pipe<=0;
  else release_pipe<={release_pipe[0],1'b1};
 assign reset_n=release_pipe[1];
endmodule
`default_nettype wire
