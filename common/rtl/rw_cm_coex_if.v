`default_nettype none
module rw_cm_coex_if(
 input wire clk,rst_n,enable,request,grant_async,
 output wire granted,
 output wire request_out
);
 (* ASYNC_REG="TRUE" *) reg [1:0] grant_sync;
 always @(posedge clk or negedge rst_n)
  if(!rst_n) grant_sync<=0;else grant_sync<={grant_sync[0],grant_async};
 assign granted=!enable||grant_sync[1];assign request_out=enable&&request;
endmodule
`default_nettype wire
