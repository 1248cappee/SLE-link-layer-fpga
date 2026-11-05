`default_nettype none
// Three clients: host, scheduler, packet engine. Byte addresses, registered
// responses, round-robin fairness. A request is held until its response.
module rw_ble_em_cntl #(parameter integer EM_BYTES=131072)(
 input wire clk,rst_n,
 input wire [2:0] req,write,
 input wire [50:0] addr,
 input wire [95:0] wdata,
 input wire [11:0] be,
 output reg [2:0] ack,fault,
 output reg [31:0] rdata,
 output wire busy
);
 (* ram_style="block" *) reg [31:0] mem[0:EM_BYTES/4-1];
 reg [1:0] state,owner,next_owner;
 reg [16:0] saved_addr;
 reg [31:0] saved_data,read_data;
 reg [3:0] saved_be;
 reg saved_write,saved_fault;
 integer b;
 reg [1:0] selected;
 reg found;
 always @* begin
  selected=next_owner; found=0;
  case(next_owner)
   0: if(req[0]) begin selected=0;found=1;end else if(req[1]) begin selected=1;found=1;end else if(req[2]) begin selected=2;found=1;end
   1: if(req[1]) begin selected=1;found=1;end else if(req[2]) begin selected=2;found=1;end else if(req[0]) begin selected=0;found=1;end
   default: if(req[2]) begin selected=2;found=1;end else if(req[0]) begin selected=0;found=1;end else if(req[1]) begin selected=1;found=1;end
  endcase
 end
 // Synchronous RAM access, deliberately outside the resettable controller.
 always @(posedge clk) if(state==1 && !saved_fault) begin
  read_data<=mem[saved_addr[16:2]];
  if(saved_write) for(b=0;b<4;b=b+1)
   if(saved_be[b]) mem[saved_addr[16:2]][b*8+:8]<=saved_data[b*8+:8];
 end
 assign busy=state!=0;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   state<=0;owner<=0;next_owner<=0;ack<=0;fault<=0;rdata<=0;
   saved_addr<=0;saved_data<=0;saved_be<=0;saved_write<=0;saved_fault<=0;
  end else begin
   ack<=0;fault<=0;
   case(state)
    0: if(found) begin
     owner<=selected;saved_addr<=addr[selected*17+:17];
     saved_data<=wdata[selected*32+:32];saved_be<=be[selected*4+:4];
     saved_write<=write[selected];
     saved_fault<=(addr[selected*17+:17]>=EM_BYTES || addr[selected*17+:2]!=0);
     state<=1;
    end
    1: state<=2;
    2: begin
     ack[owner]<=1;fault[owner]<=saved_fault;rdata<=saved_fault?0:read_data;
     next_owner<=(owner==2)?0:owner+1'b1;state<=3;
    end
    3: if(!req[owner]) state<=0;
   endcase
  end
 end
 // synthesis translate_off
 initial if(EM_BYTES<1024 || EM_BYTES>131072 || EM_BYTES%4!=0) $fatal(1,"EM_BYTES range/alignment");
 // synthesis translate_on
endmodule
`default_nettype wire
