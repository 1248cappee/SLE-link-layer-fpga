`default_nettype none
// First octet [127:120]; state is serialized in AES column order.
module rw_cm_aes_shiftrows(input wire [127:0] state_in,output wire [127:0] state_out);
 genvar column,row;
 generate for(column=0;column<4;column=column+1) begin:columns
  for(row=0;row<4;row=row+1) begin:rows
   assign state_out[127-(column*4+row)*8-:8]=state_in[127-(((column+row)%4)*4+row)*8-:8];
  end
 end endgenerate
endmodule
`default_nettype wire
