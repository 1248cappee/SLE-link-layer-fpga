`default_nettype none
module sle_cm_sm4_cipher #(parameter integer STEPS=1)(
 input wire clk,rst_n,start,input wire [127:0] key,block_in,
 output reg busy,done,output reg [127:0] block_out
);
 reg [5:0] round;reg [127:0] data_state,key_state;
 wire [127:0] data_chain[0:STEPS],key_chain[0:STEPS];
 assign data_chain[0]=data_state;assign key_chain[0]=key_state;
 genvar s;
 generate for(s=0;s<STEPS;s=s+1) begin:rounds
  wire [127:0] next_key,next_data;wire [31:0] round_key;
  wire [5:0] round_index=round+s;
  sle_cm_sm4_keyexpansion keys(.key_in(key_chain[s]),.round(round_index),.key_out(next_key),.round_key(round_key));
  sle_cm_sm4_round datapath(.state_in(data_chain[s]),.round_key(round_key),.state_out(next_data));
  assign key_chain[s+1]=(round+s<32)?next_key:key_chain[s];
  assign data_chain[s+1]=(round+s<32)?next_data:data_chain[s];
 end endgenerate
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin busy<=0;done<=0;round<=0;data_state<=0;key_state<=0;block_out<=0;end
  else begin
   done<=0;
   if(start && !busy) begin
    busy<=1;round<=0;data_state<=block_in;key_state<=key^128'ha3b1bac656aa3350677d9197b27022dc;
   end else if(busy) begin
    data_state<=data_chain[STEPS];key_state<=key_chain[STEPS];
    if(round+STEPS>=32) begin
     block_out<={data_chain[STEPS][31:0],data_chain[STEPS][63:32],data_chain[STEPS][95:64],data_chain[STEPS][127:96]};
     busy<=0;done<=1;
    end else round<=round+STEPS;
   end
  end
 end
endmodule
`default_nettype wire
