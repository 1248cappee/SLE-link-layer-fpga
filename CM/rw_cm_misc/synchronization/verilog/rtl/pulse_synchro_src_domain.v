`default_nettype none
module pulse_synchro_src_domain(
 input wire clk,rst_n,pulse,ack_async,
 output reg request,overflow,
 output wire ready
);
 wire ack;
 simple_synchro a(.clk(clk),.rst_n(rst_n),.async_in(ack_async),.sync_out(ack));
 assign ready=request==ack;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin request<=0;overflow<=0;end
  else if(pulse)begin if(ready)request<=!request;else overflow<=1;end
endmodule
`default_nettype wire
