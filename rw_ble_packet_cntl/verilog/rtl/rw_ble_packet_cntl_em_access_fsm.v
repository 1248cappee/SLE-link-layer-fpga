`default_nettype none
// Halfword/word access adapter. Unaligned words are rejected, never split
// into two non-atomic writes. Requests and responses have independent timing.
module rw_ble_packet_cntl_em_access_fsm(
 input wire clk,rst_n,req,write,halfword,
 input wire [16:0] addr,
 input wire [31:0] wdata,
 input wire [3:0] be,
 output reg ack,fault,
 output reg [31:0] rdata,
 output reg em_req,em_write,
 output reg [16:0] em_addr,
 output reg [31:0] em_wdata,
 output reg [3:0] em_be,
 input wire em_ack,em_fault,
 input wire [31:0] em_rdata
);
 reg [1:0] state;
 reg upper,half;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin state<=0;ack<=0;fault<=0;rdata<=0;em_req<=0;em_write<=0;em_addr<=0;em_wdata<=0;em_be<=0;upper<=0;half<=0;end
  else begin
   ack<=0;fault<=0;
   case(state)
    0:if(req) begin
     if(addr[0] || (!halfword && addr[1])) begin ack<=1;fault<=1;state<=2;end
     else begin
      upper<=addr[1];half<=halfword;em_req<=1;em_write<=write;em_addr<={addr[16:2],2'd0};
      em_wdata<=halfword?(addr[1]?{wdata[15:0],16'd0}:{16'd0,wdata[15:0]}):wdata;
      em_be<=halfword?(addr[1]?4'b1100:4'b0011):be;state<=1;
     end
    end
    1:if(em_ack) begin
     em_req<=0;ack<=1;fault<=em_fault;rdata<=half?(upper?{16'd0,em_rdata[31:16]}:{16'd0,em_rdata[15:0]}):em_rdata;state<=2;
    end
    2:if(!req) state<=0;
    default:state<=0;
   endcase
  end
 end
endmodule
`default_nettype wire
