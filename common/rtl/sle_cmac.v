`default_nettype none
// AES/SM4 CMAC for a single 0..16-octet message, used by random-identifier
// resolution. The first message octet is message[127:120].
module sle_cmac(
 input wire clk,rst_n,start,algorithm,
 input wire [127:0] key,message,
 input wire [4:0] message_bytes,
 output reg busy,done,error,
 output reg [127:0] result
);
 reg [2:0] state;
 reg alg,go;
 reg [127:0] saved_key,saved_message,block;
 reg [4:0] length;
 wire cipher_done,cipher_busy;
 wire [127:0] cipher_result;
 reg [127:0] k1,k2,pad;
 integer i;
 sle_block_cipher cipher(.clk(clk),.rst_n(rst_n),.start(go),.algorithm(alg),.key(saved_key),.block_in(block),.busy(cipher_busy),.done(cipher_done),.block_out(cipher_result));
 always @* begin
  k1=(cipher_result<<1)^(cipher_result[127]?128'h87:128'd0);
  k2=(k1<<1)^(k1[127]?128'h87:128'd0);pad=0;
  for(i=0;i<16;i=i+1) begin
   if(i<length) pad[127-i*8-:8]=saved_message[127-i*8-:8];
   else if(i==length) pad[127-i*8-:8]=8'h80;
  end
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin state<=0;busy<=0;done<=0;error<=0;result<=0;alg<=0;go<=0;saved_key<=0;saved_message<=0;block<=0;length<=0;end
  else begin
   go<=0;done<=0;
   case(state)
    0:if(start) begin
     error<=message_bytes>16;
     if(message_bytes>16) done<=1;
     else begin busy<=1;alg<=algorithm;saved_key<=key;saved_message<=message;length<=message_bytes;state<=1;end
    end
    1:begin block<=0;go<=1;state<=2;end
    2:if(cipher_done) begin block<=length==16?(saved_message^k1):(pad^k2);go<=1;state<=3;end
    3:if(cipher_done) begin result<=cipher_result;busy<=0;done<=1;state<=0;end
    default:state<=0;
   endcase
  end
 end
endmodule
`default_nettype wire
