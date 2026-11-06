`timescale 1ns/1ps
module tb_cm;
 reg [2:0] selection;reg enabled=1;
 reg [29:0] target_slot,origin_slot;
 reg [9:0] target_fine,origin_fine;wire legal;
 sle_schedule_grid grid(.*);
 integer unit,s,offset;
 reg [29:0] dd;longint signed reference_distance;integer seed=19381;
 initial begin
  for(s=0;s<5;s=s+1)begin
   selection=s;unit=(s+1)*50;
   for(offset=-400;offset<=400;offset=offset+1)begin
    origin_slot=30'h3fffffff;origin_fine=100;
    if(100+offset<0)begin target_slot=30'h3ffffffe;target_fine=350+offset;end
    else if(100+offset<250)begin target_slot=30'h3fffffff;target_fine=100+offset;end
    else if(100+offset<500)begin target_slot=0;target_fine=offset-150;end
    else begin target_slot=1;target_fine=offset-400;end
    // Restrict each constructed fine value to its canonical representation.
    if(target_fine<250)begin
     #1;if(legal!==((offset%unit)==0))$fatal(1,"grid s=%d offset=%d legal=%b",s,offset,legal);
    end
   end
  end
  selection=5;#1;if(legal)$fatal(1,"reserved grid accepted");
  for(integer n=0;n<10000;n=n+1)begin
   selection=n%5;unit=(n%5+1)*50;
   origin_slot=$random(seed);target_slot=$random(seed);
   origin_fine=($random(seed)&32'h7fffffff)%250;target_fine=($random(seed)&32'h7fffffff)%250;
   dd=target_slot-origin_slot;reference_distance=$signed(dd);
   reference_distance=reference_distance*250+$signed({1'b0,target_fine})-$signed({1'b0,origin_fine});
   #1;if(legal!==((dd!=30'h20000000)&&((reference_distance%unit)==0)))$fatal(1,"wide grid residue mismatch %d %d",selection,reference_distance);
  end
  enabled=0;#1;if(!legal)$fatal(1,"legacy grid disabled");
  $display("SLE_TEST_PASS: tb_cm");$finish;
 end
endmodule
