`default_nettype none
// One AES-128 forward round key. Registers belong to aes_top and are
// transaction scoped; no software writes can change an active round key.
module rw_cm_aes_keyexpansion(
 input wire [127:0] key_in,input wire [7:0] rcon_in,
 output wire [127:0] key_out,output wire [7:0] rcon_out
);
 wire [31:0] subword;
 rw_cm_aes_sbox s0(.sbox_in(key_in[23:16]),.sbox_out(subword[31:24]));
 rw_cm_aes_sbox s1(.sbox_in(key_in[15:8]),.sbox_out(subword[23:16]));
 rw_cm_aes_sbox s2(.sbox_in(key_in[7:0]),.sbox_out(subword[15:8]));
 rw_cm_aes_sbox s3(.sbox_in(key_in[31:24]),.sbox_out(subword[7:0]));
 wire [31:0] w0=key_in[127:96]^subword^{rcon_in,24'd0};
 wire [31:0] w1=key_in[95:64]^w0,w2=key_in[63:32]^w1,w3=key_in[31:0]^w2;
 assign key_out={w0,w1,w2,w3};
 assign rcon_out={rcon_in[6:0],1'b0} ^ (8'h1b & {8{rcon_in[7]}});
endmodule
`default_nettype wire
