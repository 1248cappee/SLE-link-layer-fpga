`default_nettype none
// Forward AES substitution. SLE CCM uses this direction for TX and RX.
module rw_cm_aes_sbox(input wire [7:0] sbox_in,output wire [7:0] sbox_out);
 `include "sle_sboxes.vh"
 assign sbox_out=aes_sbox(sbox_in);
endmodule
`default_nettype wire
