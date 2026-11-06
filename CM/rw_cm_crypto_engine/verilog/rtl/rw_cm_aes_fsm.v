`default_nettype none
// Iterative round ownership. STEPS may be non-divisor of ten; the datapath
// bypasses surplus rounds and completes exactly once after the tenth round.
module rw_cm_aes_fsm #(parameter integer STEPS=1)(
 input wire clk,rst_n,start,
 output reg busy,done,output reg [3:0] round,
 output wire accept,last_round
);
 assign accept=start && !busy;
 assign last_round=(round+STEPS>10);
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin busy<=0;done<=0;round<=0;end
  else begin
   done<=0;
   if(accept) begin busy<=1;round<=1;end
   else if(busy) begin
    if(last_round) begin busy<=0;done<=1;end
    else round<=round+STEPS;
   end
  end
 end
endmodule
`default_nettype wire
