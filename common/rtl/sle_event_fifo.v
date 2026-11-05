`default_nettype none
module sle_event_fifo #(parameter integer DEPTH=64)(
 input wire clk,rst_n,push,pop,
 input wire [71:0] in_event,
 output wire [71:0] head,
 output reg [7:0] count,
 output wire full,empty,
 output reg overflow
);
 reg [71:0] memory[0:DEPTH-1];
 reg [7:0] rp,wp;
 wire take=pop && !empty;
 wire put=push && (!full || take);
 assign empty=count==0;
 assign full=count==DEPTH;
 assign head=empty ? 72'd0 : memory[rp];
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin rp<=0; wp<=0; count<=0; overflow<=0; end
  else begin
   if(push && !put) overflow<=1;
   if(put) begin memory[wp]<=in_event; wp<=(wp==DEPTH-1)?0:wp+1'b1; end
   if(take) rp<=(rp==DEPTH-1)?0:rp+1'b1;
   case({put,take})
    2'b10: count<=count+1'b1;
    2'b01: count<=count-1'b1;
    default: count<=count;
   endcase
  end
 end
 // synthesis translate_off
 initial if(DEPTH<2 || DEPTH>255) $fatal(1,"FIFO depth must be 2..255");
 // synthesis translate_on
endmodule
`default_nettype wire
