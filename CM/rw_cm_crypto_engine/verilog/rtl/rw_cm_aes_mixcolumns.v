`default_nettype none
module rw_cm_aes_mixcolumns(input wire [31:0] column_in,output wire [31:0] column_out);
 function [7:0] xtime;
  input [7:0] x;
  begin xtime={x[6:0],1'b0} ^ (8'h1b & {8{x[7]}});end
 endfunction
 wire [7:0] a=column_in[31:24],b=column_in[23:16],c=column_in[15:8],d=column_in[7:0];
 assign column_out={xtime(a)^xtime(b)^b^c^d,a^xtime(b)^xtime(c)^c^d,
                    a^b^xtime(c)^xtime(d)^d,xtime(a)^a^b^c^xtime(d)};
endmodule
`default_nettype wire
