`default_nettype none
// Native RX mailbox transport and ordered stop. There is no fabricated read
// response or drain acknowledgement. A stopped PHY must provide drain_done.
module rw_cm_radio_cntl #(parameter integer TIMEOUT_CYCLES=1000000)(
 input wire clk,rst_n,
 input wire s_req,s_write,
 input wire [7:0] s_addr,
 input wire [31:0] s_wdata,
 output wire s_rvalid,
 output wire [31:0] s_rdata,
 output wire mac_req,mac_write,
 output wire [7:0] mac_addr,
 output wire [31:0] mac_wdata,
 input wire mac_rvalid,
 input wire [31:0] mac_rdata,
 input wire stop,drain_done,
 output wire stop_done,
 output reg fault
);
 reg [2:0] state;
 reg pending;
 reg [31:0] age;
 wire response_ready,response_valid;
 rw_cm_jitter_elim_fifo response_buffer(.clk(clk),.rst_n(rst_n),.in_data(mac_rdata),
  .in_valid(mac_rvalid&&pending),.in_ready(response_ready),.out_data(s_rdata),
  .out_valid(response_valid),.out_ready(1'b1));
 assign s_rvalid=response_valid;
 assign mac_req=(state==0)?s_req:(state>=1&&state<=3);
 assign mac_write=(state==0)?s_write:1'b1;
 assign mac_addr=(state==0)?s_addr:(state==1?8'h3c:8'h00);
 assign mac_wdata=(state==0)?s_wdata:(state==1?32'd1:(state==2?32'h00000208:32'h80000204));
 assign stop_done=state==4&&drain_done&&!pending;
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin state<=0;pending<=0;age<=0;fault<=0;end
  else begin
   if(state==0 && s_req&&!s_write) begin
    if(pending) fault<=1;
    pending<=1;age<=0;
   end
   if(mac_rvalid&&(!pending||!response_ready))fault<=1;
   if(s_rvalid)pending<=0;
   if(pending) begin if(age==TIMEOUT_CYCLES-1) fault<=1;else age<=age+1'b1;end
   case(state)
    0:if(stop&&!pending&&!s_req) state<=1;
    1:state<=2;2:state<=3;3:state<=4;
    4:if(!stop&&drain_done) state<=0;
    default:state<=0;
   endcase
  end
 end
endmodule
`default_nettype wire
