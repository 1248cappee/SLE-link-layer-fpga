`timescale 1ns/1ps
module tb_bus;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,hsel=0,hwrite=0;wire hready;wire hready_in=hready;
 reg [17:0] haddr=0;reg [1:0] htrans=0;reg [2:0] hsize=2;reg [31:0] hwdata=0;
 wire [1:0] hresp;wire [31:0] hrdata;wire req,write;wire [17:0] addr;wire [31:0] wdata;wire [3:0] be;
 reg ack=0,error=0;reg [31:0] rdata=0;reg [31:0] words[0:15];reg held=0;
 integer writes=0;reg [31:0] value;
 rw_cm_ahb_if ahb(.*);
 always @(posedge clk)begin
  ack<=0;
  if(!rst_n)held<=0;
  else if(req&&!held)begin
   held<=1;ack<=1;rdata<=words[addr[5:2]];
   if(write)begin
    writes<=writes+1;for(integer b=0;b<4;b=b+1)if(be[b])words[addr[5:2]][b*8+:8]<=wdata[b*8+:8];
   end
  end else if(!req)held<=0;
 end
 task transaction(input bit wr,input [17:0] a,input [2:0] size,input [31:0] d,input bit bad,output [31:0] q);
  @(negedge clk);hsel=1;htrans=2;haddr=a;hwrite=wr;hsize=size;
  do @(posedge clk);while(!hready);
  @(negedge clk);hsel=0;htrans=0;hwdata=d;
  do begin @(posedge clk);#1;end while(!hready);
  if(hresp!==(bad?2'b01:2'b00))$fatal(1,"AHB response");q=hrdata;
  @(negedge clk);
 endtask
 reg [2:0] mreq=0,mwrite=0;reg [50:0] maddr=0;reg [95:0] mdata=0;reg [11:0] mbe=0;
 wire [2:0] mack,mfault;wire [31:0] mrdata;wire mbusy;
 rw_ble_em_cntl #(.EM_BYTES(1024)) memory(.clk(clk),.rst_n(rst_n),.req(mreq),.write(mwrite),.addr(maddr),.wdata(mdata),.be(mbe),.ack(mack),.fault(mfault),.rdata(mrdata),.busy(mbusy));
 integer serviced,expected_owner;
 task concurrent_memory(input bit wr);
  @(negedge clk);mreq=7;mwrite=wr?7:0;mbe=12'hfff;maddr={17'd8,17'd4,17'd0};mdata={32'h33333333,32'h22222222,32'h11111111};
  serviced=0;expected_owner=0;
  while(serviced<3)begin
   @(negedge clk);
   for(integer k=0;k<3;k=k+1)if(mack[k])begin
    if(k!=expected_owner||mfault[k])$fatal(1,"EM arbitration order/fault");
    if(!wr&&mrdata!==(32'h11111111*(k+1)))$fatal(1,"EM registered read response");
    mreq[k]=0;serviced=serviced+1;expected_owner=expected_owner+1;
   end
  end
  repeat(3)@(negedge clk);
 endtask
 initial begin
  for(integer k=0;k<16;k=k+1)words[k]=0;
  repeat(4)@(negedge clk);rst_n=1;
  transaction(1,0,2,32'h11223344,0,value);
  transaction(1,2,1,32'haabb0000,0,value);
  transaction(1,1,0,32'h0000cc00,0,value);
  transaction(0,0,2,0,0,value);if(value!==32'haabbcc44||writes!=3)$fatal(1,"AHB byte/halfword/word");
  transaction(1,2,2,0,1,value);transaction(1,0,3,0,1,value);if(writes!=3)$fatal(1,"illegal AHB transfer reached EM");
  concurrent_memory(1);concurrent_memory(0);
  @(negedge clk);mreq=1;mwrite=0;maddr=1024;mbe=15;
  wait(mack[0]);#1;if(!mfault[0]||mrdata!=0)$fatal(1,"EM out of range not rejected");@(negedge clk);mreq=0;
  $display("SLE_TEST_PASS: tb_bus");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
