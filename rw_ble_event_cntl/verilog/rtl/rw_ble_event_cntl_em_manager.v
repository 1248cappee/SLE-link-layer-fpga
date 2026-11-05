`default_nettype none
module rw_ble_event_cntl_em_manager #(parameter integer EM_BYTES=131072)(
 input wire [1167:0] cs,
 input wire [2:0] et_mode,
 output wire valid,
 output wire [13:0] tx_ptr,rx_ptr,
 output wire [15:0] min_time,max_time,rx_window,rx_max_time,rx_max_bytes
);
 assign tx_ptr=cs[18*16+:14];assign rx_ptr=cs[17*16+:14];
 assign min_time=cs[23*16+:16];assign max_time=cs[24*16+:16];
 assign rx_window=cs[15*16+:16];assign rx_max_time=cs[29*16+:16];assign rx_max_bytes=cs[28*16+:16];
 assign valid=cs[2:0]==et_mode && et_mode<4 && max_time!=0 && min_time<=max_time &&
  (tx_ptr==0 || ((({3'd0,tx_ptr}<<1)+16<=EM_BYTES)&&(({3'd0,tx_ptr}<<1)+16<=32768))) &&
  (rx_ptr==0 || ((({3'd0,rx_ptr}<<1)+28<=EM_BYTES)&&(({3'd0,rx_ptr}<<1)+28<=32768)));
endmodule
`default_nettype wire
