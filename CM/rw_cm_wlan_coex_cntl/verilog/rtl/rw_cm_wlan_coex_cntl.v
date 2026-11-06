`default_nettype none
module rw_cm_wlan_coex_cntl(
 input wire enable,local_tx,local_rx,peer_busy,
 input wire [4:0] local_priority,peer_priority,
 output wire request,grant
);
 assign request=local_tx||local_rx;
 rw_cm_timing_gen_coex priority_policy(.enable(enable),.request(request),.peer_busy(peer_busy),
  .local_priority(local_priority),.peer_priority(peer_priority),.granted(grant));
endmodule
`default_nettype wire
