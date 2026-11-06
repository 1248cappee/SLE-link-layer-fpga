`default_nettype none
module rw_cm_int_cntl(
 input wire clk,rst_n,
 input wire [5:0] mask, ack,
 input wire [2:0] timer_fire,
 input wire clock_fire,fifo_nonempty,error_level,
 output wire [5:0] status,
 output wire irq,
 output wire [2:0] timer_irq
);
 reg [3:0] sticky;
 always @(posedge clk or negedge rst_n)
  if(!rst_n) sticky<=0;
  else sticky<=(sticky & ~{ack[5],ack[3:1]}) | {clock_fire,timer_fire};
 assign status={sticky[3],error_level,sticky[2:0],fifo_nonempty};
 assign irq=|(status & mask);
 assign timer_irq=status[3:1] & mask[3:1];
endmodule
`default_nettype wire
