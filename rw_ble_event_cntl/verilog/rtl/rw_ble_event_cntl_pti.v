`default_nettype none
module rw_ble_event_cntl_pti(
 input wire [4:0] priority,
 input wire tx,rx,coex_enable,grant,
 output wire [4:0] pti,
 output wire allowed
);
 assign pti=(tx||rx)?priority:5'd0;
 assign allowed=!coex_enable||grant;
endmodule
`default_nettype wire
