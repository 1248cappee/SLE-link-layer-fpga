`default_nettype none
module sle_cm_sm4_round(input wire [127:0] state_in,input wire [31:0] round_key,
 output wire [127:0] state_out);
 `include "sle_sboxes.vh"
 wire [31:0] x=state_in[95:64]^state_in[63:32]^state_in[31:0]^round_key;
 wire [31:0] t={sm4_sbox(x[31:24]),sm4_sbox(x[23:16]),sm4_sbox(x[15:8]),sm4_sbox(x[7:0])};
 wire [31:0] word_out=state_in[127:96]^t^{t[29:0],t[31:30]}^{t[21:0],t[31:22]}
                     ^{t[13:0],t[31:14]}^{t[7:0],t[31:8]};
 assign state_out={state_in[95:0],word_out};
endmodule
`default_nettype wire
