`default_nettype none
// Role 2: mode mask 0x5. Policy only; execution is in packet control.
module rw_ble_event_cntl_master(
 input wire [3:0] role,
 input wire [2:0] mode,
 output wire selected,mode_allowed
);
 assign selected=role==4'd2;
 assign mode_allowed=selected && mode<4 && ((4'h5>>mode)&1'b1);
endmodule
`default_nettype wire
