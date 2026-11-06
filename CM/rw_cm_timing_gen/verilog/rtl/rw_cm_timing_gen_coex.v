`default_nettype none
// Priority arbitration is evaluated against a stable same-domain snapshot.
// SLE does not inherit Bluetooth half-slot bandwidth/priority-timer semantics.
module rw_cm_timing_gen_coex(
 input wire enable,request,peer_busy,
 input wire [4:0] local_priority,peer_priority,
 output wire granted
);
 assign granted=!enable||!peer_busy||(request&&local_priority>peer_priority);
endmodule
`default_nettype wire
