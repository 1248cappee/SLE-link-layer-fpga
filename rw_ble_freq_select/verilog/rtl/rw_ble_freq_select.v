`default_nettype none
// SLE 6.10.3: three byte-wise PERM / MAM stages and multiply-high remap.
// This P101 integration profile implements the 76 data channels at 2.4 GHz.
module rw_ble_freq_select(
 input wire clk,rst_n,start,
 input wire [29:0] slot,
 input wire [31:0] sync_or_llid,
 input wire [75:0] channel_map,
 output reg done,error,
 output reg [6:0] channel,
 output reg [15:0] random_value
);
 reg [15:0] seed,value,permuted;
 reg [6:0] used,initial_channel,mapped;
 reg [31:0] product;
 reg [2:0] state;
 integer i;
 always @* begin
  for(i=0;i<8;i=i+1) begin permuted[i]=value[7-i];permuted[i+8]=value[15-i];end
  used=0;for(i=0;i<76;i=i+1) if(channel_map[i]) used=used+1'b1;
  product=random_value*used;
  mapped=0;
  for(i=0;i<76;i=i+1) if(channel_map[i]) begin
   if(mapped==product[22:16]) begin end
   mapped=mapped+1'b1;
  end
 end
 reg [6:0] ordinal;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin state<=0;done<=0;error<=0;channel<=0;random_value<=0;seed<=0;value<=0;ordinal<=0;initial_channel<=0;end
  else begin
   done<=0;
   case(state)
    0:if(start) begin seed<=sync_or_llid[15:0]^sync_or_llid[31:16];value<=slot[15:0]^sync_or_llid[15:0]^sync_or_llid[31:16];error<=0;state<=1;end
    1,2,3:begin value<=(permuted*16'd17)+seed;state<=state+1'b1;end
    4:begin random_value<=value^seed;state<=5;end
    5:begin initial_channel<=random_value%76;state<=6;end
    6:begin
     if(used<2) begin error<=1;channel<=0;end
     else if(channel_map[initial_channel]) channel<=initial_channel;
     else begin
      ordinal=0;
      for(i=0;i<76;i=i+1) if(channel_map[i]) begin if(ordinal==product[22:16]) channel<=i;ordinal=ordinal+1'b1;end
     end
     done<=1;state<=0;
    end
    default:state<=0;
   endcase
  end
 end
endmodule
`default_nettype wire
