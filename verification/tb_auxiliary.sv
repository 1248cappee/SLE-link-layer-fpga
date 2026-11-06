`timescale 1ns/1ps
module tb_auxiliary;
 reg clk=0;always #25 clk=~clk;
 reg rst_n=0,start=0,aux_freeze=0;reg [29:0] slot=1;reg [31:0] sync_or_llid=0;reg [75:0] channel_map={76{1'b1}};
 wire done,error;wire [6:0] channel;wire [15:0] random_value;
 rw_ble_freq_select hop(.*);
 reg ls=0,la=0,ev=0,el=0,lr=0;reg [47:0] wanted=48'h123456789abc,mask=48'hffffffffffff,address=0;reg [15:0] tag=0;
 wire er,lb,lv,lm;wire [15:0] lt;
 rw_ble_list_search_engine list(.freeze(aux_freeze),.clk(clk),.rst_n(rst_n),.start(ls),.abort(la),.wanted(wanted),.mask(mask),.invert(1'b0),
 .entry_valid(ev),.entry_last(el),.entry_address(address),.entry_tag(tag),.entry_ready(er),.busy(lb),.result_valid(lv),.matched(lm),.result_tag(lt),.result_ready(lr));
 reg rs=0,ra=0,rv=0,rl=0,rr=0;reg [15:0] ri=0,rt=0;
 wire ready,rb,rvalid,matched,rerror;wire [15:0] result_tag;
 rw_ble_ral_search_engine resolve(.freeze(aux_freeze),.clk(clk),.rst_n(rst_n),.start(rs),.abort(ra),.algorithm(1'b0),.wanted_irk_id(16'h12),.wanted_hash(16'h6746),
 .random_message(128'd0),.random_bytes(5'd0),.entry_valid(rv),.entry_last(rl),.entry_irk_id(ri),.entry_tag(rt),
 .entry_key(128'h2b7e151628aed2a6abf7158809cf4f3c),.entry_ready(ready),.busy(rb),.result_valid(rvalid),.matched(matched),.error(rerror),.result_tag(result_tag),.result_ready(rr));
 task pulse_hop;
  @(negedge clk);start=1;@(negedge clk);start=0;wait(done);#1;
 endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  aux_freeze=1;ls=1;rs=1;@(negedge clk);ls=0;rs=0;@(negedge clk);if(lb||rb)$fatal(1,"auxiliary accepted start while frozen");aux_freeze=0;
  pulse_hop();if(error||random_value!==16'h9108||channel!=40)$fatal(1,"SLE PRN / first mapping");
  channel_map=(76'd1<<75)|1;pulse_hop();if(error||channel!=75)$fatal(1,"multiply-high remap");
  channel_map=1;pulse_hop();if(!error)$fatal(1,"one usable channel accepted");
  @(negedge clk);ls=1;@(negedge clk);ls=0;
  ev=1;address=0;tag=1;@(negedge clk);address=wanted;tag=7;el=1;@(negedge clk);ev=0;el=0;
  if(!lv||!lm||lt!=7)$fatal(1,"filter match/tag");repeat(3)@(negedge clk);if(!lv||lt!=7)$fatal(1,"filter result not stable");lr=1;@(negedge clk);lr=0;
  rs=1;@(negedge clk);rs=0;rv=1;ri=1;rt=1;rl=0;@(negedge clk);ri='h12;rt=9;rl=1;@(negedge clk);rv=0;
  wait(rvalid);#1;if(rerror||!matched||result_tag!=9)$fatal(1,"IRK/CMAC resolution");
  @(negedge clk);rr=1;@(negedge clk);rr=0;
  rs=1;@(negedge clk);rs=0;rv=1;ri='h12;rt=9;rl=1;@(negedge clk);rv=0;
  repeat(5)@(negedge clk);ra=1;@(negedge clk);ra=0;repeat(50)@(negedge clk);
  if(rb||rvalid)$fatal(1,"resolution abort not drained");
  $display("SLE_TEST_PASS: tb_auxiliary");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
