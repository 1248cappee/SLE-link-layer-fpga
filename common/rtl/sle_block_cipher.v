`default_nettype none
// Encryption primitive for CTR and CBC-MAC. AES-128: 10 rounds;
// SM4: 32 rounds with simultaneous round-key expansion. Standard byte order:
// first input octet is bits [127:120]. CTR decryption uses this same primitive.
module sle_block_cipher #(parameter integer AES_STEPS=1,SM4_STEPS=1)(
 input wire clk,rst_n,start,algorithm,
 input wire [127:0] key,block_in,
 output reg busy,done,
 output reg [127:0] block_out
);
 `include "sle_sboxes.vh"
 reg alg;
 reg [5:0] round;
 reg [127:0] data_state,key_state;
 reg [7:0] rcon;
 localparam integer MAX_STEPS=(AES_STEPS>SM4_STEPS)?AES_STEPS:SM4_STEPS;
 reg [127:0] next_data,next_key;
 reg [7:0] next_rcon;
 reg [31:0] sm4_ck,sm4_t,sm4_k,sm4_x;
 integer step;
 function [7:0] xtime;
  input [7:0] x;
  begin xtime={x[6:0],1'b0} ^ (8'h1b & {8{x[7]}});end
 endfunction
 function [31:0] rol;
  input [31:0] x;
  input integer n;
  begin rol=(x<<n)|(x>>(32-n));end
 endfunction
 function [31:0] tau;
  input [31:0] x;
  begin tau={sm4_sbox(x[31:24]),sm4_sbox(x[23:16]),sm4_sbox(x[15:8]),sm4_sbox(x[7:0])};end
 endfunction
 function [127:0] expand_aes_key;
  input [127:0] k;
  input [7:0] rc;
  reg [31:0] t,w0,w1,w2,w3;
  begin
   t={aes_sbox(k[23:16])^rc,aes_sbox(k[15:8]),aes_sbox(k[7:0]),aes_sbox(k[31:24])};
   w0=k[127:96]^t;w1=k[95:64]^w0;w2=k[63:32]^w1;w3=k[31:0]^w2;expand_aes_key={w0,w1,w2,w3};
  end
 endfunction
 function [127:0] aes_round;
  input [127:0] data,key_round;
  input last_round;
  reg [127:0] sub,shift,mix;
  reg [7:0] a,b,c,d;
  integer i,col,row;
  begin
   for(i=0;i<16;i=i+1) sub[127-i*8-:8]=aes_sbox(data[127-i*8-:8]);
   for(col=0;col<4;col=col+1) for(row=0;row<4;row=row+1)
    shift[127-(col*4+row)*8-:8]=sub[127-(((col+row)%4)*4+row)*8-:8];
   for(col=0;col<4;col=col+1) begin
    a=shift[127-col*32-:8];b=shift[119-col*32-:8];c=shift[111-col*32-:8];d=shift[103-col*32-:8];
    mix[127-col*32-:32]={xtime(a)^xtime(b)^b^c^d,a^xtime(b)^xtime(c)^c^d,a^b^xtime(c)^xtime(d)^d,xtime(a)^a^b^c^xtime(d)};
   end
   aes_round=(last_round?shift:mix)^key_round;
  end
 endfunction
 always @* begin
  next_data=data_state;next_key=key_state;next_rcon=rcon;
  sm4_ck=0;sm4_t=0;sm4_k=0;sm4_x=0;
  for(step=0;step<MAX_STEPS;step=step+1) begin
   if(!alg && step<AES_STEPS && round+step<=10) begin
    next_key=expand_aes_key(next_key,next_rcon);next_rcon=xtime(next_rcon);
    next_data=aes_round(next_data,next_key,round+step==10);
   end
   if(alg && step<SM4_STEPS && round+step<32) begin
    sm4_ck[31:24]=(((round+step)*4+0)*7)&255;sm4_ck[23:16]=(((round+step)*4+1)*7)&255;
    sm4_ck[15:8]=(((round+step)*4+2)*7)&255;sm4_ck[7:0]=(((round+step)*4+3)*7)&255;
    sm4_t=tau(next_key[95:64]^next_key[63:32]^next_key[31:0]^sm4_ck);
    sm4_k=next_key[127:96]^sm4_t^rol(sm4_t,13)^rol(sm4_t,23);
    sm4_t=tau(next_data[95:64]^next_data[63:32]^next_data[31:0]^sm4_k);
    sm4_x=next_data[127:96]^sm4_t^rol(sm4_t,2)^rol(sm4_t,10)^rol(sm4_t,18)^rol(sm4_t,24);
    next_key={next_key[95:0],sm4_k};next_data={next_data[95:0],sm4_x};
   end
  end
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin busy<=0;done<=0;block_out<=0;alg<=0;round<=0;data_state<=0;key_state<=0;rcon<=0;end
  else begin
   done<=0;
   if(start && !busy) begin
    alg<=algorithm;busy<=1;round<=algorithm?0:1;rcon<=1;
    key_state<=algorithm?(key^128'ha3b1bac656aa3350677d9197b27022dc):key;
    data_state<=algorithm?block_in:(block_in^key);
   end else if(busy) begin
    if(!alg) begin
     key_state<=next_key;rcon<=next_rcon;data_state<=next_data;
     if(round+AES_STEPS>10) begin block_out<=next_data;busy<=0;done<=1;end
     else round<=round+AES_STEPS;
    end else begin
     key_state<=next_key;data_state<=next_data;
     if(round+SM4_STEPS>=32) begin block_out<={next_data[31:0],next_data[63:32],next_data[95:64],next_data[127:96]};busy<=0;done<=1;end
     else round<=round+SM4_STEPS;
    end
   end
  end
 end
endmodule
`default_nettype wire
