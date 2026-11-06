`default_nettype none
// AHB-Lite-compatible single-transfer slave; address and data phases separate.
module rw_cm_ahb_if(
 input wire clk,rst_n,hsel,hready_in,
 input wire [17:0] haddr,
 input wire [1:0] htrans,
 input wire hwrite,
 input wire [2:0] hsize,
 input wire [31:0] hwdata,
 output wire hready,
 output wire [1:0] hresp,
 output wire [31:0] hrdata,
 output wire req,write,
 output wire [17:0] addr,
 output wire [31:0] wdata,
 output wire [3:0] be,
 input wire ack,error,
 input wire [31:0] rdata
);
 reg selection;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)selection<=0;else if(hready&&hready_in&&hsel&&htrans[1])selection<=haddr[17];
 wire reg_hready;
 wire [1:0] reg_hresp;
 wire [31:0] reg_hrdata;
 wire reg_req;
 wire reg_write;
 wire [17:0] reg_addr;
 wire [31:0] reg_wdata;
 wire [3:0] reg_be;
 rw_cm_ahb_if_ahb2reg reg_path(.clk(clk),.rst_n(rst_n),.hsel(hsel&&(haddr[17]==1'b0)),.hready_in(hready_in),.haddr(haddr),.htrans(htrans),.hwrite(hwrite),.hsize(hsize),.hwdata(hwdata),.hready(reg_hready),.hresp(reg_hresp),.hrdata(reg_hrdata),.req(reg_req),.write(reg_write),.addr(reg_addr),.wdata(reg_wdata),.be(reg_be),.ack(ack&&reg_req),.error(error),.rdata(rdata));
 wire em_hready;
 wire [1:0] em_hresp;
 wire [31:0] em_hrdata;
 wire em_req;
 wire em_write;
 wire [17:0] em_addr;
 wire [31:0] em_wdata;
 wire [3:0] em_be;
 rw_cm_ahb_if_ahb2em em_path(.clk(clk),.rst_n(rst_n),.hsel(hsel&&(haddr[17]==1'b1)),.hready_in(hready_in),.haddr(haddr),.htrans(htrans),.hwrite(hwrite),.hsize(hsize),.hwdata(hwdata),.hready(em_hready),.hresp(em_hresp),.hrdata(em_hrdata),.req(em_req),.write(em_write),.addr(em_addr),.wdata(em_wdata),.be(em_be),.ack(ack&&em_req),.error(error),.rdata(rdata));
 assign hready=selection?em_hready:reg_hready;
 assign hresp=selection?em_hresp:reg_hresp;
 assign hrdata=selection?em_hrdata:reg_hrdata;
 assign req=selection?em_req:reg_req;
 assign write=selection?em_write:reg_write;
 assign addr=selection?em_addr:reg_addr;
 assign wdata=selection?em_wdata:reg_wdata;
 assign be=selection?em_be:reg_be;
endmodule
`default_nettype wire
