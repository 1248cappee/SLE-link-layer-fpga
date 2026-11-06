`default_nettype none
// AHB-Lite-compatible single-transfer slave; address and data phases separate.
module rw_cm_ahb_if_ahb2reg(
 input wire clk,rst_n,hsel,hready_in,
 input wire [17:0] haddr,
 input wire [1:0] htrans,
 input wire hwrite,
 input wire [2:0] hsize,
 input wire [31:0] hwdata,
 output wire hready,
 output wire [1:0] hresp,
 output wire [31:0] hrdata,
 output reg req,write,
 output reg [17:0] addr,
 output reg [31:0] wdata,
 output reg [3:0] be,
 input wire ack,error,
 input wire [31:0] rdata
);
 reg [2:0] state;
 reg [1:0] lane;
 reg [2:0] size;
 reg bad;
 reg [31:0] result;
 wire address_valid=hsel && hready_in && htrans[1];
 assign hready=state==0 || state==3 || state==5;
 assign hresp=(state==4 || state==5)?2'b01:2'b00;
 assign hrdata=result;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin state<=0;req<=0;write<=0;addr<=0;wdata<=0;be<=0;lane<=0;size<=0;bad<=0;result<=0;end
  else begin
   case(state)
    0,3,5: begin
     if(address_valid) begin
      write<=hwrite;addr<={haddr[17:2],2'b00};lane<=haddr[1:0];size<=hsize;
      bad<=hsize>2 || (hsize==2 && haddr[1:0]!=0) || (hsize==1 && haddr[0]);state<=1;
     end else state<=0;
    end
    1: begin
     if(bad) state<=4;
     else begin
      wdata<=hwdata;
      case(size) 0:be<=4'b0001<<lane;1:be<=4'b0011<<lane;default:be<=4'b1111;endcase
      req<=1;state<=2;
     end
    end
    2: if(ack) begin req<=0;result<=rdata;state<=error?4:3;end
    4: state<=5; // two-cycle AHB ERROR response
    default: state<=0;
   endcase
  end
 end
endmodule
`default_nettype wire
