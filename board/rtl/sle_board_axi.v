`default_nettype none
module sle_board_axi(
 (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 clk CLK", X_INTERFACE_PARAMETER="ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET rst_n, FREQ_HZ 20000000" *) input wire clk,
 (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 rst_n RST", X_INTERFACE_PARAMETER="POLARITY ACTIVE_LOW" *) input wire rst_n,
 input wire [31:0] s_axi_awaddr,input wire [2:0] s_axi_awprot,input wire s_axi_awvalid,output wire s_axi_awready,
 input wire [31:0] s_axi_wdata,input wire [3:0] s_axi_wstrb,input wire s_axi_wvalid,output wire s_axi_wready,
 output wire [1:0] s_axi_bresp,output wire s_axi_bvalid,input wire s_axi_bready,
 input wire [31:0] s_axi_araddr,input wire [2:0] s_axi_arprot,input wire s_axi_arvalid,output wire s_axi_arready,
 output wire [31:0] s_axi_rdata,output wire [1:0] s_axi_rresp,output wire s_axi_rvalid,input wire s_axi_rready,
 output wire [383:0] trace
);
 wire req,wr,wait_i,error;wire [18:0] addr;wire [31:0] data,rdata;wire [3:0] be;
 sle_axi_xbar bridge(.clk(clk),.rst_n(rst_n),
 .s_awaddr(s_axi_awaddr),.s_awvalid(s_axi_awvalid),.s_awready(s_axi_awready),
 .s_wdata(s_axi_wdata),.s_wstrb(s_axi_wstrb),.s_wvalid(s_axi_wvalid),.s_wready(s_axi_wready),
 .s_bresp(s_axi_bresp),.s_bvalid(s_axi_bvalid),.s_bready(s_axi_bready),
 .s_araddr(s_axi_araddr),.s_arvalid(s_axi_arvalid),.s_arready(s_axi_arready),
 .s_rdata(s_axi_rdata),.s_rresp(s_axi_rresp),.s_rvalid(s_axi_rvalid),.s_rready(s_axi_rready),
 .req(req),.wr(wr),.addr(addr),.data(data),.be(be),.wait_i(wait_i),.rdata(rdata),.error(error));
 sle_board_core core(.clk(clk),.rst_n(rst_n),.host_req(req),.host_write(wr),.host_addr(addr),
 .host_wdata(data),.host_be(be),.host_wait(wait_i),.host_rdata(rdata),.host_error(error),.trace(trace));
endmodule
`default_nettype wire
