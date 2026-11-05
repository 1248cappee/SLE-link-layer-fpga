`default_nettype none
// Native 32-bit payload transport across the preserved RW boundaries.
module rw_ble_lr_fec_dec(
 input wire clk,rst_n,
 input wire [31:0] s_data,
 input wire [3:0] s_keep,
 input wire s_valid,s_last,
 output wire s_ready,
 output wire [31:0] m_data,
 output wire [3:0] m_keep,
 output wire m_valid,m_last,
 input wire m_ready
);
 wire [3:0] valid,ready,last;
 wire [127:0] data;
 wire [15:0] keep;
 assign valid[0]=s_valid;assign last[0]=s_last;assign data[31:0]=s_data;assign keep[3:0]=s_keep;assign s_ready=ready[0];
 assign m_valid=valid[3];assign m_last=last[3];assign m_data=data[96+:32];assign m_keep=keep[12+:4];assign ready[3]=m_ready;
 rw_ble_lr_fec_dec_fifo u_rw_ble_lr_fec_dec_fifo(.clk(clk),.rst_n(rst_n),.s_data(data[0+:32]),.s_keep(keep[0+:4]),.s_valid(valid[0]),.s_last(last[0]),.s_ready(ready[0]),.m_data(data[32+:32]),.m_keep(keep[4+:4]),.m_valid(valid[1]),.m_last(last[1]),.m_ready(ready[1]));
 rw_ble_lr_fec_dec_viterbi u_rw_ble_lr_fec_dec_viterbi(.clk(clk),.rst_n(rst_n),.s_data(data[32+:32]),.s_keep(keep[4+:4]),.s_valid(valid[1]),.s_last(last[1]),.s_ready(ready[1]),.m_data(data[64+:32]),.m_keep(keep[8+:4]),.m_valid(valid[2]),.m_last(last[2]),.m_ready(ready[2]));
 rw_ble_lr_fec_dec_fsm u_rw_ble_lr_fec_dec_fsm(.clk(clk),.rst_n(rst_n),.s_data(data[64+:32]),.s_keep(keep[8+:4]),.s_valid(valid[2]),.s_last(last[2]),.s_ready(ready[2]),.m_data(data[96+:32]),.m_keep(keep[12+:4]),.m_valid(valid[3]),.m_last(last[3]),.m_ready(ready[3]));
endmodule
`default_nettype wire
