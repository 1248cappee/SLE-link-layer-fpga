`default_nettype none
// Role 7: mode mask 0xc. Policy only; execution is in packet control.
module rw_ble_event_cntl_cisslave(
 input wire [3:0] role,
 input wire [2:0] mode,
 output wire selected,mode_allowed
);
 assign selected=role==4'd7;
 assign mode_allowed=selected && mode<4 && ((4'hc>>mode)&1'b1);
endmodule
`default_nettype wire
