`default_nettype none
module pulse_synchro_dst_domain(
 input wire clk,rst_n,request_async,
 output reg pulse,ack
);
 wire request;
 simple_synchro r(.clk(clk),.rst_n(rst_n),.async_in(request_async),.sync_out(request));
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin ack<=0;pulse<=0;end
  else begin pulse<=request!=ack;ack<=request;end
endmodule
`default_nettype wire
