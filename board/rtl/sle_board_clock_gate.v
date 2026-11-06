`default_nettype none
module sle_board_clock_gate(
 input wire clk,rst_n,enable,
 output wire gated_clk
);
`ifdef SYNTHESIS
 BUFGCE #(.SIM_DEVICE("7SERIES")) gate_buffer(.I(clk),.CE(enable||!rst_n),.O(gated_clk));
`else
 reg enabled=1;
 always @(negedge clk)enabled<=enable||!rst_n;
 assign gated_clk=clk&&enabled;
`endif
endmodule
`default_nettype wire
