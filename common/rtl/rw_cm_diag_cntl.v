`default_nettype none
module rw_cm_diag_cntl(
 input wire clk,rst_n,clear,access,write,
 input wire [16:0] address,
 output reg [16:0] minimum,maximum,
 output reg [31:0] read_count,write_count
);
 always @(posedge clk or negedge rst_n)
  if(!rst_n) begin minimum<=17'h1ffff;maximum<=0;read_count<=0;write_count<=0;end
  else if(clear) begin minimum<=17'h1ffff;maximum<=0;read_count<=0;write_count<=0;end
  else if(access) begin
   if(address<minimum) minimum<=address;if(address>maximum) maximum<=address;
   if(write) write_count<=write_count+1'b1;else read_count<=read_count+1'b1;
  end
endmodule
`default_nettype wire
