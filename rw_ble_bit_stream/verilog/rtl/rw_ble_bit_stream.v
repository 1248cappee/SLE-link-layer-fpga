`default_nettype none
// Native 32-bit payload transport across the preserved RW boundaries.
module rw_ble_bit_stream(
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
 wire [9:0] valid,ready,last;
 wire [319:0] data;
 wire [39:0] keep;
 assign valid[0]=s_valid;assign last[0]=s_last;assign data[31:0]=s_data;assign keep[3:0]=s_keep;assign s_ready=ready[0];
 assign m_valid=valid[9];assign m_last=last[9];assign m_data=data[288+:32];assign m_keep=keep[36+:4];assign ready[9]=m_ready;
 rw_ble_lr_fec_enc u_rw_ble_lr_fec_enc(.clk(clk),.rst_n(rst_n),.s_data(data[0+:32]),.s_keep(keep[0+:4]),.s_valid(valid[0]),.s_last(last[0]),.s_ready(ready[0]),.m_data(data[32+:32]),.m_keep(keep[4+:4]),.m_valid(valid[1]),.m_last(last[1]),.m_ready(ready[1]));
 rw_ble_lr_pdemap u_rw_ble_lr_pdemap(.clk(clk),.rst_n(rst_n),.s_data(data[32+:32]),.s_keep(keep[4+:4]),.s_valid(valid[1]),.s_last(last[1]),.s_ready(ready[1]),.m_data(data[64+:32]),.m_keep(keep[8+:4]),.m_valid(valid[2]),.m_last(last[2]),.m_ready(ready[2]));
 rw_ble_lr_pdetect u_rw_ble_lr_pdetect(.clk(clk),.rst_n(rst_n),.s_data(data[64+:32]),.s_keep(keep[8+:4]),.s_valid(valid[2]),.s_last(last[2]),.s_ready(ready[2]),.m_data(data[96+:32]),.m_keep(keep[12+:4]),.m_valid(valid[3]),.m_last(last[3]),.m_ready(ready[3]));
 rw_ble_whitening u_rw_ble_whitening(.clk(clk),.rst_n(rst_n),.s_data(data[96+:32]),.s_keep(keep[12+:4]),.s_valid(valid[3]),.s_last(last[3]),.s_ready(ready[3]),.m_data(data[128+:32]),.m_keep(keep[16+:4]),.m_valid(valid[4]),.m_last(last[4]),.m_ready(ready[4]));
 rw_ble_crc u_rw_ble_crc(.clk(clk),.rst_n(rst_n),.s_data(data[128+:32]),.s_keep(keep[16+:4]),.s_valid(valid[4]),.s_last(last[4]),.s_ready(ready[4]),.m_data(data[160+:32]),.m_keep(keep[20+:4]),.m_valid(valid[5]),.m_last(last[5]),.m_ready(ready[5]));
 rw_ble_lr_pdecoder u_rw_ble_lr_pdecoder(.clk(clk),.rst_n(rst_n),.s_data(data[160+:32]),.s_keep(keep[20+:4]),.s_valid(valid[5]),.s_last(last[5]),.s_ready(ready[5]),.m_data(data[192+:32]),.m_keep(keep[24+:4]),.m_valid(valid[6]),.m_last(last[6]),.m_ready(ready[6]));
 rw_ble_lr_pmap u_rw_ble_lr_pmap(.clk(clk),.rst_n(rst_n),.s_data(data[192+:32]),.s_keep(keep[24+:4]),.s_valid(valid[6]),.s_last(last[6]),.s_ready(ready[6]),.m_data(data[224+:32]),.m_keep(keep[28+:4]),.m_valid(valid[7]),.m_last(last[7]),.m_ready(ready[7]));
 rw_ble_lr_psynchro u_rw_ble_lr_psynchro(.clk(clk),.rst_n(rst_n),.s_data(data[224+:32]),.s_keep(keep[28+:4]),.s_valid(valid[7]),.s_last(last[7]),.s_ready(ready[7]),.m_data(data[256+:32]),.m_keep(keep[32+:4]),.m_valid(valid[8]),.m_last(last[8]),.m_ready(ready[8]));
 rw_ble_lr_fec_dec u_rw_ble_lr_fec_dec(.clk(clk),.rst_n(rst_n),.s_data(data[256+:32]),.s_keep(keep[32+:4]),.s_valid(valid[8]),.s_last(last[8]),.s_ready(ready[8]),.m_data(data[288+:32]),.m_keep(keep[36+:4]),.m_valid(valid[9]),.m_last(last[9]),.m_ready(ready[9]));
endmodule
`default_nettype wire
