`default_nettype none
// Forward primitive for both SLE CCM directions (CTR decryption is forward
// AES). The reference inverse-block branch is outside this build profile.
module rw_cm_aes_cipher_decipher #(parameter integer STEPS=1)(
 input wire [127:0] state_in,key_in,input wire [7:0] rcon_in,input wire [3:0] round,
 output wire [127:0] state_out,key_out,output wire [7:0] rcon_out
);
 wire [127:0] data_chain[0:STEPS],key_chain[0:STEPS];
 wire [7:0] rcon_chain[0:STEPS];
 assign data_chain[0]=state_in;assign key_chain[0]=key_in;assign rcon_chain[0]=rcon_in;
 assign state_out=data_chain[STEPS];assign key_out=key_chain[STEPS];assign rcon_out=rcon_chain[STEPS];
 genvar s,b,c;
 generate for(s=0;s<STEPS;s=s+1) begin:rounds
  wire [127:0] expanded,substituted,shifted,mixed;
  wire [7:0] expanded_rcon;
  rw_cm_aes_keyexpansion keys(.key_in(key_chain[s]),.rcon_in(rcon_chain[s]),
   .key_out(expanded),.rcon_out(expanded_rcon));
  for(b=0;b<16;b=b+1) begin:bytes
   rw_cm_aes_sbox sub(.sbox_in(data_chain[s][127-b*8-:8]),.sbox_out(substituted[127-b*8-:8]));
  end
  rw_cm_aes_shiftrows shift(.state_in(substituted),.state_out(shifted));
  for(c=0;c<4;c=c+1) begin:columns
   rw_cm_aes_mixcolumns mix(.column_in(shifted[127-c*32-:32]),.column_out(mixed[127-c*32-:32]));
  end
  assign data_chain[s+1]=(round+s<=10)?(((round+s==10)?shifted:mixed)^expanded):data_chain[s];
  assign key_chain[s+1]=(round+s<=10)?expanded:key_chain[s];
  assign rcon_chain[s+1]=(round+s<=10)?expanded_rcon:rcon_chain[s];
 end endgenerate
endmodule
`default_nettype wire
