`default_nettype none
module rw_cm_diag_cntl(
 input wire clk,rst_n,clear,access,write,
 input wire [16:0] address,
 input wire freeze,waiting,fault,
 input wire [1:0] source,
 output reg [16:0] minimum,maximum,
 output reg [31:0] read_count,write_count,wait_count,fault_count,first_fault,
 output reg [3:0] first_info
);
 reg first_valid;
 always @(posedge clk or negedge rst_n)
  if(!rst_n) begin minimum<=17'h1ffff;maximum<=0;read_count<=0;write_count<=0;
   wait_count<=0;fault_count<=0;first_fault<=0;first_info<=0;first_valid<=0;end
  else if(clear) begin minimum<=17'h1ffff;maximum<=0;read_count<=0;write_count<=0;
   wait_count<=0;fault_count<=0;first_fault<=0;first_info<=0;first_valid<=0;end
  else if(!(freeze===1'b1)) begin
   if(waiting===1'b1)wait_count<=wait_count+1'b1;
   if(fault===1'b1)begin
    fault_count<=fault_count+1'b1;
    if(!first_valid)begin first_fault<={15'd0,address};first_info<={1'b1,write,source};first_valid<=1;end
   end
   if(access)begin
    if(address<minimum) minimum<=address;if(address>maximum) maximum<=address;
    if(write) write_count<=write_count+1'b1;else read_count<=read_count+1'b1;
   end
  end
endmodule
`default_nettype wire
