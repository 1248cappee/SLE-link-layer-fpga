`default_nettype none
module rw_ble_event_cntl_scanch(
 input wire clk,rst_n,start,advance,
 input wire [78:0] channels,
 output reg valid,done,
 output reg [6:0] channel
);
 reg [78:0] remaining;
 reg [6:0] candidate;
 reg found;
 integer i;
 always @* begin candidate=0;found=0;for(i=0;i<79;i=i+1) if(remaining[i]&&!found) begin candidate=i;found=1;end end
 always @(posedge clk or negedge rst_n)
  if(!rst_n) begin remaining<=0;valid<=0;done<=0;channel<=0;end
  else begin
   done<=0;
   if(start) begin remaining<=channels;valid<=0;end
   else if(!valid) begin
    if(found) begin channel<=candidate;valid<=1;end
   end else if(advance) begin remaining[channel]<=0;valid<=0;if((remaining & ~(79'd1<<channel))==0) done<=1;end
  end
endmodule
`default_nettype wire
