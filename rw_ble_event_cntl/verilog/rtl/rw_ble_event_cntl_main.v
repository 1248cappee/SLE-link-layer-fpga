`default_nettype none
module rw_ble_event_cntl_main(
 input wire clk,rst_n,accept,complete,abandon,cancel,
 input wire mode_allowed,
 output reg active,
 output wire cancel_out,
 output wire [2:0] mode_error
);
 assign cancel_out=cancel&&active;
 assign mode_error=mode_allowed?3'd0:3'd7;
 always @(posedge clk or negedge rst_n)
  if(!rst_n) active<=0;
  else if(complete||abandon) active<=0;
  else if(accept) active<=1;
endmodule
`default_nettype wire
