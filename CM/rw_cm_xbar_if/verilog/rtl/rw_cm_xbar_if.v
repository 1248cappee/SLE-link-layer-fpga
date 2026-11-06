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
 output wire req,write,
 output wire [17:0] addr,
 output wire [31:0] wdata,
 output wire [3:0] be,
 input wire ack,error,
 input wire [31:0] rdata
);
 wire selection=p_ad[17];
 wire reg_p_wait;
 wire [31:0] reg_p_rdata;
 wire reg_p_error;
 wire reg_req;
 wire reg_write;
 wire [17:0] reg_addr;
 wire [31:0] reg_wdata;
 wire [3:0] reg_be;
 rw_cm_xbar_if_xbar2reg reg_path(.clk(clk),.rst_n(rst_n),.p_rd(p_rd&&(selection==1'b0)),.p_wr(p_wr&&(selection==1'b0)),.p_ad(p_ad),.p_wdata(p_wdata),.p_ben(p_ben),.p_wait(reg_p_wait),.p_rdata(reg_p_rdata),.p_error(reg_p_error),.req(reg_req),.write(reg_write),.addr(reg_addr),.wdata(reg_wdata),.be(reg_be),.ack(ack&&reg_req),.error(error),.rdata(rdata));
 wire em_p_wait;
 wire [31:0] em_p_rdata;
 wire em_p_error;
 wire em_req;
 wire em_write;
 wire [17:0] em_addr;
 wire [31:0] em_wdata;
 wire [3:0] em_be;
 rw_cm_xbar_if_xbar2em em_path(.clk(clk),.rst_n(rst_n),.p_rd(p_rd&&(selection==1'b1)),.p_wr(p_wr&&(selection==1'b1)),.p_ad(p_ad),.p_wdata(p_wdata),.p_ben(p_ben),.p_wait(em_p_wait),.p_rdata(em_p_rdata),.p_error(em_p_error),.req(em_req),.write(em_write),.addr(em_addr),.wdata(em_wdata),.be(em_be),.ack(ack&&em_req),.error(error),.rdata(rdata));
 assign p_wait=selection?em_p_wait:reg_p_wait;
 assign p_rdata=selection?em_p_rdata:reg_p_rdata;
 assign p_error=selection?em_p_error:reg_p_error;
 assign req=selection?em_req:reg_req;
 assign write=selection?em_write:reg_write;
 assign addr=selection?em_addr:reg_addr;
 assign wdata=selection?em_wdata:reg_wdata;
 assign be=selection?em_be:reg_be;
endmodule
`default_nettype wire
