`default_nettype none
// Streaming whitelist / masked-address engine. First matching entry wins;
// each entry is consumed exactly once, including under result backpressure.
module rw_ble_list_search_engine(
 input wire clk,rst_n,start,abort,
 input wire [47:0] wanted,mask,
 input wire invert,
 input wire entry_valid,entry_last,
 input wire [47:0] entry_address,
 input wire [15:0] entry_tag,
 output wire entry_ready,
 output reg busy,result_valid,matched,
 output reg [15:0] result_tag,
 input wire result_ready
);
 reg [47:0] target,saved_mask;
 reg negated,found;
 reg [15:0] first_tag;
 wire hit=((entry_address & saved_mask)==(target & saved_mask));
 assign entry_ready=busy&&!result_valid;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin busy<=0;result_valid<=0;matched<=0;result_tag<=0;target<=0;saved_mask<=0;negated<=0;found<=0;first_tag<=0;end
  else begin
   if(result_valid&&result_ready) result_valid<=0;
   if(start&&!busy&&!result_valid) begin busy<=1;target<=wanted;saved_mask<=mask;negated<=invert;found<=0;first_tag<=0;end
   if(entry_valid&&entry_ready) begin
    if(hit&&!found) begin found<=1;first_tag<=entry_tag;end
    if(entry_last) begin
     busy<=0;result_valid<=1;matched<=(found||hit)^negated;
     result_tag<=found?first_tag:(hit?entry_tag:16'd0);
    end
   end
   if(abort) begin busy<=0;result_valid<=0;end
  end
 end
endmodule
`default_nettype wire
