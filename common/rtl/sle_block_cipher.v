`default_nettype none
// Algorithm ownership and stable result boundary. Both CCM encryption and
// decryption use a forward block cipher; no AES inverse datapath is selected.
module sle_block_cipher #(parameter integer AES_STEPS=1,SM4_STEPS=1)(
 input wire clk,rst_n,start,algorithm,
 input wire [127:0] key,block_in,
 output wire busy,done,
 output wire [127:0] block_out
);
 reg selected;
 reg [127:0] last_result;
 wire aes_busy,aes_done,sm4_busy,sm4_done;
 wire [127:0] aes_result,sm4_result;
 wire accept=start && !busy;
 assign busy=selected?sm4_busy:aes_busy;
 assign done=selected?sm4_done:aes_done;
 wire [127:0] result=selected?sm4_result:aes_result;
 // Preserve the previous result across algorithm changes until the new DONE.
 assign block_out=done?result:last_result;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin selected<=0;last_result<=0;end
  else begin
   if(accept) selected<=algorithm;
   if(done) last_result<=result;
  end
 end
 rw_cm_aes_top #(.STEPS(AES_STEPS)) aes(
  .clk(clk),.rst_n(rst_n),.start(accept && !algorithm),.key(key),.block_in(block_in),
  .busy(aes_busy),.done(aes_done),.block_out(aes_result));
 sle_cm_sm4_cipher #(.STEPS(SM4_STEPS)) sm4(
  .clk(clk),.rst_n(rst_n),.start(accept && algorithm),.key(key),.block_in(block_in),
  .busy(sm4_busy),.done(sm4_done),.block_out(sm4_result));
endmodule
`default_nettype wire
