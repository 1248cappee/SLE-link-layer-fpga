`default_nettype none
// Streaming TX CCM: a 16-word input FIFO overlaps EM reads with independent
// CBC-MAC and CTR primitives. Each input word is accepted once; the final MIC
// is packed into the last partial word without overwriting a payload octet.
module sle_ccm_stream_tx(
 input wire clk,rst_n,start,algorithm,auth_only,
 input wire [127:0] key,
 input wire [103:0] nonce,
 input wire [10:0] length,
 input wire [31:0] s_data,
 input wire s_valid,
 output wire s_ready,
 output wire [31:0] m_data,
 output wire [3:0] m_keep,
 output wire m_valid,m_last,
 input wire m_ready,
 output reg busy,done,error
);
 localparam IDLE=0,INIT=1,INIT_WAIT=2,AAD=3,AAD_WAIT=4,LOAD=5,BLOCK=6,BLOCK_WAIT=7,OUTPUT=8;
 reg [3:0] state;
 reg [31:0] fifo[0:15];
 reg [3:0] rp,wp;
 reg [4:0] count;
 reg [1:0] word_index;
 reg [10:0] bytes,offset;
 reg [4:0] block_bytes,out_bytes;
 reg alg,only_auth,cbc_go,ctr_go;
 reg [127:0] saved_key,plain,mac,cbc_input,ctr_input;
 reg [103:0] saved_nonce;
 reg [31:0] s0;
 reg [159:0] out_shift;
 reg [7:0] block_index;
 wire cbc_busy,ctr_busy,cbc_done,ctr_done;
 wire [127:0] cbc_result,ctr_result;
 reg [127:0] ciphertext;
 reg [31:0] tag;
 wire take=s_valid&&s_ready;
 wire consume=state==LOAD&&count!=0;
 assign s_ready=busy&&count<16;
 assign m_valid=state==OUTPUT;
 assign m_data=out_shift[31:0];
 assign m_last=m_valid&&(offset+block_bytes==bytes)&&out_bytes<=4;
 assign m_keep=out_bytes>=4?4'hf:(out_bytes==3?4'h7:(out_bytes==2?4'h3:4'h1));
 function [31:0] swap;
  input [31:0] v;
  begin swap={v[7:0],v[15:8],v[23:16],v[31:24]};end
 endfunction
 function [127:0] reverse_words;
  input [127:0] v;
  begin reverse_words={swap(v[31:0]),swap(v[63:32]),swap(v[95:64]),swap(v[127:96])};end
 endfunction
 integer b;
 reg [31:0] padded;
 always @* begin
  padded=0;
  for(b=0;b<4;b=b+1) if(word_index*4+b<block_bytes) padded[b*8+:8]=fifo[rp][b*8+:8];
  ciphertext=only_auth?plain:(plain^ctr_result);
  tag=swap(cbc_result[127:96]^s0);
 end
 sle_block_cipher #(.AES_STEPS(2),.SM4_STEPS(4)) cbc(.clk(clk),.rst_n(rst_n),.start(cbc_go),.algorithm(alg),.key(saved_key),
  .block_in(cbc_input),.busy(cbc_busy),.done(cbc_done),.block_out(cbc_result));
 sle_block_cipher #(.AES_STEPS(2),.SM4_STEPS(4)) ctr(.clk(clk),.rst_n(rst_n),.start(ctr_go),.algorithm(alg),.key(saved_key),
  .block_in(ctr_input),.busy(ctr_busy),.done(ctr_done),.block_out(ctr_result));
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   state<=IDLE;rp<=0;wp<=0;count<=0;word_index<=0;bytes<=0;offset<=0;block_bytes<=0;out_bytes<=0;
   alg<=0;only_auth<=0;cbc_go<=0;ctr_go<=0;saved_key<=0;plain<=0;mac<=0;cbc_input<=0;ctr_input<=0;
   saved_nonce<=0;s0<=0;out_shift<=0;block_index<=0;busy<=0;done<=0;error<=0;
  end else begin
   done<=0;cbc_go<=0;ctr_go<=0;
   if(take) begin fifo[wp]<=s_data;wp<=wp+1'b1;end
   if(consume) rp<=rp+1'b1;
   case({take,consume}) 2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:begin end endcase
   case(state)
    IDLE:if(start) begin
     rp<=0;wp<=0;count<=0;bytes<=length;offset<=0;block_index<=0;word_index<=0;
     saved_key<=key;saved_nonce<=nonce;alg<=algorithm;only_auth<=auth_only;plain<=0;mac<=0;error<=0;busy<=1;
     if(length>2043) begin error<=1;done<=1;busy<=0;end else state<=INIT;
    end
    INIT:begin
     cbc_input<={8'h49,saved_nonce,5'd0,bytes};ctr_input<={8'h01,saved_nonce,16'd0};cbc_go<=1;ctr_go<=1;state<=INIT_WAIT;
    end
    INIT_WAIT:if(cbc_done&&ctr_done) begin mac<=cbc_result;s0<=ctr_result[127:96];state<=AAD;end
    AAD:begin cbc_input<=mac^128'h00010000000000000000000000000000;cbc_go<=1;state<=AAD_WAIT;end
    AAD_WAIT:if(cbc_done) begin
     mac<=cbc_result;block_bytes<=bytes>=16?16:bytes;plain<=0;word_index<=0;
     if(bytes==0) begin out_shift<={128'd0,tag};out_bytes<=4;state<=OUTPUT;end
     else state<=LOAD;
    end
    LOAD:if(consume) begin
     plain[127-word_index*32-:32]<=swap(padded);
     if((word_index+1)*4>=block_bytes) state<=BLOCK;
     else word_index<=word_index+1'b1;
    end
    BLOCK:begin
     cbc_input<=mac^plain;ctr_input<={8'h01,saved_nonce,8'd0,block_index+8'd1};cbc_go<=1;ctr_go<=1;state<=BLOCK_WAIT;
    end
    BLOCK_WAIT:if(cbc_done&&ctr_done) begin
     mac<=cbc_result;
     if(offset+block_bytes==bytes) begin
      out_shift<=({32'd0,reverse_words(ciphertext)}&((160'd1<<(block_bytes*8))-1'b1))|({128'd0,tag}<<(block_bytes*8));out_bytes<=block_bytes+4;
     end
     else begin out_shift<={32'd0,reverse_words(ciphertext)};out_bytes<=16;end
     state<=OUTPUT;
    end
    OUTPUT:if(m_ready) begin
     if(out_bytes<=4) begin
      if(offset+block_bytes==bytes) begin busy<=0;done<=1;state<=IDLE;end
      else begin
       offset<=offset+16;block_index<=block_index+1'b1;plain<=0;word_index<=0;
       block_bytes<=bytes-offset-16>=16?16:bytes-offset-16;state<=LOAD;
      end
     end else begin out_shift<=out_shift>>32;out_bytes<=out_bytes-4;end
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
`default_nettype wire
