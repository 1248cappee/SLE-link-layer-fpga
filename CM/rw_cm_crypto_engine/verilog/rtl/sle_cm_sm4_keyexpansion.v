`default_nettype none
// SLE addition: SM4 forward round-key schedule, first word [127:96].
module sle_cm_sm4_keyexpansion(input wire [127:0] key_in,input wire [5:0] round,
 output wire [127:0] key_out,output wire [31:0] round_key);
 `include "sle_sboxes.vh"
 wire [7:0] c0=(round*4+0)*7,c1=(round*4+1)*7,c2=(round*4+2)*7,c3=(round*4+3)*7;
 wire [31:0] x=key_in[95:64]^key_in[63:32]^key_in[31:0]^{c0,c1,c2,c3};
 wire [31:0] t={sm4_sbox(x[31:24]),sm4_sbox(x[23:16]),sm4_sbox(x[15:8]),sm4_sbox(x[7:0])};
 assign round_key=key_in[127:96]^t^{t[18:0],t[31:19]}^{t[8:0],t[31:9]};
 assign key_out={key_in[95:0],round_key};
endmodule
`default_nettype wire
