`default_nettype none
module rw_ble_misc_logic(
 input wire [2:0] frame_type,
 input wire [6:0] control_bits,
 input wire [4:0] ctrl_format,
 input wire [3:0] mcs,
 input wire [63:0] control_template,
 input wire [10:0] payload_bytes,
 input wire [1:0] crc_mode,
 output wire valid_control,
 output wire [11:0] air_data_bytes,
 output reg [63:0] native_control_bits
);
 wire short_a=ctrl_format==1||ctrl_format==2||ctrl_format==5;
 wire long_a=ctrl_format==3||ctrl_format==4||ctrl_format==6||ctrl_format==7;
 assign air_data_bytes={1'b0,payload_bytes}+((frame_type>=3)?(crc_mode==2?12'd4:12'd3):12'd0);
 assign valid_control=crc_mode!=3&&mcs<=12&&air_data_bytes<=2047&&
  ((frame_type==1&&((short_a&&control_bits==20)||(long_a&&control_bits==28))) ||
   (frame_type==2&&((short_a&&control_bits==28)||(long_a&&control_bits==36))) ||
   ((frame_type==3||frame_type==4)&&ctrl_format>=5'h11&&ctrl_format<=5'h15&&control_bits==27)) &&
  !(ctrl_format==1&&payload_bytes>255) && !(ctrl_format==5'h15&&air_data_bytes>255);
 integer bit_index,decoded_width;
 always @* begin
  native_control_bits=control_template;decoded_width=control_bits+12;
  if(frame_type==1)begin
   if(ctrl_format==1) native_control_bits[19:12]=payload_bytes[7:0];
   else if(short_a)native_control_bits[19:9]=payload_bytes;
   else if(long_a)native_control_bits[27:17]=payload_bytes;
  end else if(frame_type==2)begin
   for(bit_index=0;bit_index<4;bit_index=bit_index+1)native_control_bits[3-bit_index]=mcs[bit_index];
   for(bit_index=0;bit_index<11;bit_index=bit_index+1)
    if(ctrl_format!=1||bit_index<8)native_control_bits[decoded_width-13-bit_index]=payload_bytes[bit_index];
  end else if(frame_type==3||frame_type==4)begin
   if(ctrl_format==5'h15)begin
    for(bit_index=0;bit_index<4;bit_index=bit_index+1)native_control_bits[18-bit_index]=mcs[bit_index];
    for(bit_index=0;bit_index<8;bit_index=bit_index+1)native_control_bits[26-bit_index]=air_data_bytes[bit_index];
   end else begin
    for(bit_index=0;bit_index<4;bit_index=bit_index+1)native_control_bits[13-bit_index]=mcs[bit_index];
    for(bit_index=0;bit_index<11;bit_index=bit_index+1)native_control_bits[24-bit_index]=air_data_bytes[bit_index];
   end
  end
 end
endmodule
`default_nettype wire
