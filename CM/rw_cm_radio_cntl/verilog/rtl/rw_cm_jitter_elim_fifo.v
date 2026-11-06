`default_nettype none
// Two-entry same-clock elastic response buffer. All payload data is registered;
// output remains stable under backpressure. This is not an asynchronous FIFO.
module rw_cm_jitter_elim_fifo #(parameter integer WIDTH=32)(
 input wire clk,rst_n,
 input wire [WIDTH-1:0] in_data,
 input wire in_valid,
 output wire in_ready,
 output wire [WIDTH-1:0] out_data,
 output wire out_valid,
 input wire out_ready
);
 reg [WIDTH-1:0] first,second;
 reg [1:0] count;
 wire push=in_valid&&in_ready,pop=out_valid&&out_ready;
 assign in_ready=count<2||pop;
 assign out_valid=count!=0;assign out_data=first;
 always @(posedge clk)begin
  if(!rst_n)begin count<=0;first<=0;second<=0;end
  else case({push,pop})
   2'b10:begin if(count==0)first<=in_data;else second<=in_data;count<=count+1'b1;end
   2'b01:begin first<=second;count<=count-1'b1;end
   2'b11:if(count==1)first<=in_data;else begin first<=second;second<=in_data;end
   default:begin end
  endcase
 end
endmodule
`default_nettype wire
