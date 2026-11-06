`default_nettype none
// Signed base-slot distance from an explicit epoch. The half-range constraint
// is checked before applying the SLE scheduling grid. No target is moved.
module sle_schedule_grid(
 input wire [2:0] selection,
 input wire enabled,
 input wire [29:0] target_slot,origin_slot,
 input wire [9:0] target_fine,origin_fine,
 output wire legal
);
 wire [29:0] delta=target_slot-origin_slot;
 // Reduce the base-slot residue before comparing the fine displacement.
 // This avoids a wide combinational divide in the scheduler's check cycle.
 // 4 mod 3 = 1; 2^30 mod 3 = 1 corrects two's-complement negative deltas.
 reg [5:0] sum[0:31];
 reg signed [4:0] mod3;
 reg signed [11:0] displacement,small_distance;
 reg aligned;
 integer i;
 always @* begin
  sum[0]=0;sum[31]=0;
  for(i=0;i<15;i=i+1)sum[16+i]={4'd0,delta[i*2+:2]};
  for(i=15;i>0;i=i-1)sum[i]=sum[i*2]+sum[i*2+1];
  mod3=$signed({1'b0,(sum[1]%6'd3)})-(delta[29]?5'sd1:5'sd0);
  if(mod3<0)mod3=mod3+5'sd3;
  displacement=$signed({2'd0,target_fine})-$signed({2'd0,origin_fine});
  small_distance=displacement;aligned=0;
  case(selection)
   0:aligned=displacement==0||displacement==50||displacement==100||displacement==150||displacement==200||
             displacement==-50||displacement==-100||displacement==-150||displacement==-200;
   1:begin
    small_distance=displacement+(delta[0]?12'sd50:12'sd0);
    aligned=small_distance==0||small_distance==100||small_distance==200||small_distance==-100||small_distance==-200;
   end
   2:begin
    small_distance=displacement+(mod3==2?12'sd200:(mod3==1?12'sd100:12'sd0));
    aligned=small_distance==0||small_distance==150||small_distance==300||small_distance==-150;
   end
   3:begin
    case(delta[1:0])
     1:small_distance=displacement+12'sd50;
     2:small_distance=displacement+12'sd100;
     3:small_distance=displacement+12'sd150;
     default:small_distance=displacement;
    endcase
    aligned=small_distance==0||small_distance==200||small_distance==-200;
   end
   4:aligned=displacement==0;
   default:aligned=0;
  endcase
 end
 assign legal=!enabled || (selection<=4 && target_fine<250 && origin_fine<250 &&
                          delta!=30'h20000000 && aligned);
endmodule
`default_nettype wire
