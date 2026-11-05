`default_nettype none
// One outstanding AXI4-Lite transaction; AW and W are independently buffered.
module sle_axi_xbar(
 input wire clk,rst_n,
 input wire [31:0] s_awaddr,input wire s_awvalid,output wire s_awready,
 input wire [31:0] s_wdata,input wire [3:0] s_wstrb,input wire s_wvalid,output wire s_wready,
 output reg [1:0] s_bresp,output reg s_bvalid,input wire s_bready,
 input wire [31:0] s_araddr,input wire s_arvalid,output wire s_arready,
 output reg [31:0] s_rdata,output reg [1:0] s_rresp,output reg s_rvalid,input wire s_rready,
 output wire req,output reg wr,output reg [18:0] addr,output reg [31:0] data,
 output reg [3:0] be,input wire wait_i,input wire [31:0] rdata,input wire error
);
 reg awfull,wfull;reg [31:0] aw,wd;reg [3:0] wb;reg [1:0] state;
 assign s_awready=!awfull&&state==0&&!s_bvalid&&!s_rvalid;
 assign s_wready=!wfull&&state==0&&!s_bvalid&&!s_rvalid;
 assign s_arready=state==0&&!awfull&&!wfull&&!s_awvalid&&!s_wvalid&&!s_bvalid&&!s_rvalid;
 assign req=state==1;
 always @(posedge clk) begin
  if(!rst_n)begin state<=0;awfull<=0;wfull<=0;s_bvalid<=0;s_rvalid<=0;s_bresp<=0;s_rresp<=0;s_rdata<=0;wr<=0;addr<=0;data<=0;be<=0;aw<=0;wd<=0;wb<=0;end
  else begin
   if(s_bvalid&&s_bready)s_bvalid<=0;
   if(s_rvalid&&s_rready)s_rvalid<=0;
   if(s_awvalid&&s_awready)begin awfull<=1;aw<=s_awaddr;end
   if(s_wvalid&&s_wready)begin wfull<=1;wd<=s_wdata;wb<=s_wstrb;end
   case(state)
    0:if(awfull&&wfull)begin
     awfull<=0;wfull<=0;wr<=1;addr<=aw[18:0];data<=wd;be<=wb;
     if(aw[31:19]!=13'h800||aw[1:0]!=0||aw[18:16]>4)begin s_bvalid<=1;s_bresp<=2;end
     else state<=1;
    end else if(s_arvalid&&s_arready)begin
     wr<=0;addr<=s_araddr[18:0];data<=0;be<=15;
     if(s_araddr[31:19]!=13'h800||s_araddr[1:0]!=0||s_araddr[18:16]>4)begin s_rvalid<=1;s_rresp<=2;s_rdata<=0;end
     else state<=1;
    end
    1:if(!wait_i)begin
     state<=2;
     if(wr)begin s_bvalid<=1;s_bresp<=error?2:0;end
     else begin s_rvalid<=1;s_rresp<=error?2:0;s_rdata<=rdata;end
    end
    2:state<=0; // explicit XBAR request withdrawal
    default:state<=0;
   endcase
  end
 end
endmodule
`default_nettype wire
