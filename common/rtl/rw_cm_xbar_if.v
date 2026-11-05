`default_nettype none
module rw_cm_xbar_if(
 input wire clk,rst_n,
 input wire p_rd,p_wr,
 input wire [17:0] p_ad,
 input wire [31:0] p_wdata,
 input wire [3:0] p_ben,
 output wire p_wait,
 output wire [31:0] p_rdata,
 output wire p_error,
 output reg req,write,
 output reg [17:0] addr,
 output reg [31:0] wdata,
 output reg [3:0] be,
 input wire ack,error,
 input wire [31:0] rdata
);
 reg [1:0] state;
 reg [31:0] result;
 reg result_error;
 assign p_wait=(p_rd||p_wr) && state!=2;
 assign p_rdata=result;
 assign p_error=state==2 && result_error;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin state<=0;req<=0;write<=0;addr<=0;wdata<=0;be<=0;result<=0;result_error<=0;end
  else case(state)
   0: if(p_rd||p_wr) begin
    req<=1;write<=p_wr;addr<=p_ad;wdata<=p_wdata;be<=p_ben;state<=1;
   end
   1: if(ack) begin req<=0;result<=rdata;result_error<=error;state<=2;end
   2: if(!p_rd&&!p_wr) state<=0;
  endcase
 end
endmodule
`default_nettype wire
