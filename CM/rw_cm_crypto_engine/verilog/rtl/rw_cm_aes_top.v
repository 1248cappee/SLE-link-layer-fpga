`default_nettype none
// SLE AES-128 block engine: independent round control, key expansion and
// byte/row/column transforms. Input context is captured on accepted START.
module rw_cm_aes_top #(parameter integer STEPS=1)(
 input wire clk,rst_n,start,input wire [127:0] key,block_in,
 output wire busy,done,output reg [127:0] block_out
);
 wire accept,last_round;wire [3:0] round;
 reg [127:0] data_state,key_state;reg [7:0] rcon;
 wire [127:0] next_data,next_key;wire [7:0] next_rcon;
 rw_cm_aes_fsm #(.STEPS(STEPS)) control(.clk(clk),.rst_n(rst_n),.start(start),
  .busy(busy),.done(done),.round(round),.accept(accept),.last_round(last_round));
 rw_cm_aes_cipher_decipher #(.STEPS(STEPS)) datapath(.state_in(data_state),.key_in(key_state),
  .rcon_in(rcon),.round(round),.state_out(next_data),.key_out(next_key),.rcon_out(next_rcon));
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin data_state<=0;key_state<=0;rcon<=0;block_out<=0;end
  else if(accept) begin data_state<=block_in^key;key_state<=key;rcon<=1;end
  else if(busy) begin
   data_state<=next_data;key_state<=next_key;rcon<=next_rcon;
   if(last_round) block_out<=next_data;
  end
 end
endmodule
`default_nettype wire
