`default_nettype none
// Sequence policy shared by G/T, discovery, and synchronous role controllers.
// MODE 0 TX, 1 RX, 2 TX->RX, 3 RX->TX. CONT repeats whole sequences.
module rw_ble_packet_cntl_main_fsm(
 input wire [2:0] mode,
 input wire phase,cont,cancelled,window_expired,chain_available,
 output wire is_tx,sequence_end,repeat_sequence,valid_mode
);
 assign valid_mode=mode<4;
 assign is_tx=mode==0 || (mode==2&&!phase) || (mode==3&&phase);
 assign repeat_sequence=cont && phase && mode[1] && !cancelled && !window_expired && chain_available;
 assign sequence_end=cancelled || window_expired || !chain_available || (!mode[1]) || (phase&&!repeat_sequence);
endmodule
`default_nettype wire
