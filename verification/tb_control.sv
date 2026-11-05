`timescale 1ns/1ps
module tb_control;
 reg [2:0] frame_type=1;reg [6:0] control_bits=20;reg [4:0] ctrl_format=1;reg [3:0] mcs=0;
 reg [63:0] control_template=0;reg [10:0] payload_bytes=12;reg [1:0] crc_mode=0;
 wire valid_control;wire [11:0] air_data_bytes;wire [63:0] native_control_bits;
 rw_ble_misc_logic dut(.*);
 reg [39:0] control_word;reg [63:0] expected;
 initial begin
  #1;if(!valid_control||native_control_bits!=64'hc000)$fatal(1,"Type1 A1 map");
  payload_bytes=256;#1;if(valid_control)$fatal(1,"8-bit A1 length truncated");
  frame_type=2;ctrl_format=2;control_bits=28;mcs=10;
  control_word=0;control_word[39:36]=10;control_word[22:12]=256;expected=0;
  for(integer j=0;j<28;j=j+1)expected[j]=control_word[39-j];
  #1;if(!valid_control||native_control_bits!=expected)$fatal(1,"Type2 A2 full-length map");
  frame_type=3;ctrl_format=5'h13;control_bits=27;payload_bytes=120;mcs=6;
  #1;if(!valid_control||air_data_bytes!=123)$fatal(1,"Type3 CRC-inclusive length");
  for(integer j=0;j<11;j=j+1)if(native_control_bits[24-j]!==air_data_bytes[j])$fatal(1,"B length map");
  payload_bytes=2047;#1;if(valid_control)$fatal(1,"CRC length overflow accepted");
  $display("SLE_TEST_PASS: tb_control");$finish;
 end
endmodule
