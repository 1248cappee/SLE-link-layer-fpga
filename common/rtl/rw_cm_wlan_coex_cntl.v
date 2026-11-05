`default_nettype none
module rw_cm_wlan_coex_cntl(
 input wire enable,local_tx,local_rx,peer_busy,
 input wire [4:0] local_priority,peer_priority,
 output wire request,grant
);
 assign request=local_tx||local_rx;
 assign grant=!enable||!peer_busy||local_priority>peer_priority;
endmodule
`default_nettype wire
