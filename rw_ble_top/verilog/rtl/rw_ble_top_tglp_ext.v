`default_nettype none
module rw_ble_top_tglp_ext #(parameter integer LP_HZ=32768)(
 input wire low_power_clk,low_power_nrst,load,enable,
 input wire [29:0] load_slot,
 input wire [9:0] load_fine,
 output wire [29:0] slot,
 output wire [9:0] fine
);
 rw_cm_timing_gen_lp #(.LP_HZ(LP_HZ)) u_rw_cm_timing_gen_lp(.low_power_clk(low_power_clk),.low_power_nrst(low_power_nrst),
  .load(load),.enable(enable),.load_slot(load_slot),.load_fine(load_fine),.slot(slot),.fine(fine));
endmodule
`default_nettype wire
