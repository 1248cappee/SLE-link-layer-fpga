`default_nettype none
module falling_edge_detector(input wire clk,rst_n,level,output reg pulse);
 reg previous;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin previous<=0;pulse<=0;end
  else begin previous<=level;pulse<=!level&&previous;end
endmodule
`default_nettype wire
