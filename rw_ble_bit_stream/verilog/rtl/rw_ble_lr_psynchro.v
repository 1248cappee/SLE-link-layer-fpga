`default_nettype none
// External-PHY transport boundary. No CRC/FEC/whitening algorithm here.
module rw_ble_lr_psynchro(
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
 reg full;
 reg [36:0] payload;
 assign s_ready=!full||m_ready;
 assign m_valid=full;assign m_data=payload[31:0];assign m_keep=payload[35:32];assign m_last=payload[36];
 always @(posedge clk or negedge rst_n)
  if(!rst_n) begin full<=0;payload<=0;end
  else if(s_ready) begin full<=s_valid;if(s_valid) payload<={s_last,s_keep,s_data};end
endmodule
`default_nettype wire
