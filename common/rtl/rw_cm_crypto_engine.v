`default_nettype none
// Packet store and SLE CCM data path. Input payload octet 0 is word[7:0].
// nonce is in wire order, first nonce octet [103:96]. MIC is four octets.
// AAD is the one-octet zero associated-data field from SLE 9.3.1.3.
module rw_cm_crypto_engine(
 input wire clk,rst_n,
 input wire store_we,
 input wire [8:0] store_addr,
 input wire [31:0] store_data,
 input wire [3:0] store_be,
 input wire read_req,
 input wire [8:0] read_addr,
 output reg read_valid,
 output reg [31:0] read_data,
 input wire start,algorithm,decrypt,encrypt_payload,mic_enable,
 input wire [127:0] key,
 input wire [103:0] nonce,
 input wire [10:0] length,
 output reg busy,done,error,mic_ok,
 output reg [31:0] mic_value
);
 (* ram_style="block" *) reg [31:0] memory[0:511];
 localparam IDLE=0,S0_START=1,S0_WAIT=2,CTR_START=3,CTR_WAIT=4,CTR_READ=5,CTR_Q=6,CTR_WRITE=7,
  CBC_START=8,CBC_WAIT=9,CBC_READ=10,CBC_Q=11,TAG_READ=12,TAG_Q=13,TAG_READ2=14,TAG_Q2=15,
  TAG_WRITE=16,FINISH=17;
 reg [4:0] state;
 reg alg,dec,enc,auth,ctr_finished;
 reg [127:0] saved_key,mac,keystream,cipher_input,block_data;
 reg [103:0] saved_nonce;
 reg [10:0] bytes;
 reg [7:0] block_index,block_count;
 reg [1:0] word_index,cbc_phase;
 reg [31:0] s0,ram_q,word_result,expected0;
 reg [63:0] expected_words;
 reg [2:0] tag_byte;
 reg cipher_start;
 wire cipher_done,cipher_busy;
 wire [127:0] cipher_output;
 reg internal_we,internal_read;
 reg [8:0] internal_addr;
 reg [31:0] internal_data;
 reg [3:0] internal_be;
 integer b;
 function [31:0] swap;
  input [31:0] x;
  begin swap={x[7:0],x[15:8],x[23:16],x[31:24]};end
 endfunction
 function [31:0] padded;
  input [31:0] x;
  input [15:0] offset;
  input [10:0] n;
  integer t;
  begin padded=0;for(t=0;t<4;t=t+1) if(offset+t<n) padded[t*8+:8]=x[t*8+:8];end
 endfunction
 always @* begin
  internal_we=0;internal_read=0;internal_addr=0;internal_data=0;internal_be=0;
  case(state)
   CTR_READ,CBC_READ:begin internal_read=1;internal_addr={block_index[6:0],word_index};end
   CTR_WRITE:begin
    internal_we=1;internal_addr={block_index[6:0],word_index};internal_data=word_result;
    for(b=0;b<4;b=b+1) internal_be[b]=({block_index,4'd0}+{12'd0,word_index,2'd0}+b)<bytes;
   end
   TAG_READ:begin internal_read=1;internal_addr=bytes[10:2];end
   TAG_READ2:begin internal_read=1;internal_addr=bytes[10:2]+1'b1;end
   TAG_WRITE:begin
    internal_we=1;internal_addr=(bytes+tag_byte)>>2;
    internal_be=4'b0001<<((bytes+tag_byte)&3);
    internal_data={24'd0,mic_value[tag_byte*8+:8]}<<(((bytes+tag_byte)&3)*8);
   end
   default:begin end
  endcase
 end
 always @(posedge clk) begin
  if(internal_read) ram_q<=memory[internal_addr];
  if(read_req && !busy) read_data<=memory[read_addr];
  if(internal_we) begin
   for(b=0;b<4;b=b+1) if(internal_be[b]) memory[internal_addr][b*8+:8]<=internal_data[b*8+:8];
  end else if(store_we && !busy) begin
   for(b=0;b<4;b=b+1) if(store_be[b]) memory[store_addr][b*8+:8]<=store_data[b*8+:8];
  end
 end
 sle_block_cipher cipher(.clk(clk),.rst_n(rst_n),.start(cipher_start),.algorithm(alg),.key(saved_key),
  .block_in(cipher_input),.busy(cipher_busy),.done(cipher_done),.block_out(cipher_output));
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   state<=IDLE;busy<=0;done<=0;error<=0;mic_ok<=0;mic_value<=0;read_valid<=0;
   alg<=0;dec<=0;enc<=0;auth<=0;ctr_finished<=0;saved_key<=0;saved_nonce<=0;bytes<=0;
   mac<=0;keystream<=0;cipher_input<=0;block_data<=0;block_index<=0;block_count<=0;word_index<=0;cbc_phase<=0;
   s0<=0;word_result<=0;expected0<=0;expected_words<=0;tag_byte<=0;cipher_start<=0;
  end else begin
   read_valid<=read_req && !busy;done<=0;cipher_start<=0;
   case(state)
    IDLE:if(start) begin
     busy<=1;error<=0;mic_ok<=0;mic_value<=0;
     alg<=algorithm;dec<=decrypt;enc<=encrypt_payload;auth<=mic_enable;
     saved_key<=key;saved_nonce<=nonce;bytes<=length;block_count<=({1'b0,length}+15)>>4;
     block_index<=0;word_index<=0;cbc_phase<=0;ctr_finished<=0;mac<=0;
     if(({1'b0,length}+(mic_enable?12'd4:12'd0))>2047) begin error<=1;state<=FINISH;end
     else state<=S0_START;
    end
    S0_START:begin cipher_input<={8'h01,saved_nonce,16'd0};cipher_start<=1;state<=S0_WAIT;end
    S0_WAIT:if(cipher_done) begin
     s0<=cipher_output[127:96];block_index<=0;
     if(dec && enc && bytes!=0) state<=CTR_START;
     else if(auth) begin cbc_phase<=0;state<=CBC_START;end
     else if(enc && bytes!=0) state<=CTR_START;
     else state<=FINISH;
    end
    CTR_START:begin cipher_input<={8'h01,saved_nonce,8'd0,block_index+8'd1};cipher_start<=1;state<=CTR_WAIT;end
    CTR_WAIT:if(cipher_done) begin keystream<=cipher_output;word_index<=0;state<=CTR_READ;end
    CTR_READ:state<=CTR_Q;
    CTR_Q:begin word_result<=ram_q^swap(keystream[127-word_index*32-:32]);state<=CTR_WRITE;end
    CTR_WRITE:begin
     if(word_index==3) begin
      if(block_index+1==block_count) begin
       ctr_finished<=1;
       if(dec && auth) begin cbc_phase<=0;block_index<=0;state<=CBC_START;end
       else if(auth) begin tag_byte<=0;state<=TAG_WRITE;end
       else state<=FINISH;
      end else begin block_index<=block_index+1'b1;state<=CTR_START;end
     end else begin word_index<=word_index+1'b1;state<=CTR_READ;end
    end
    CBC_START:begin
     if(cbc_phase==0) cipher_input<={8'h49,saved_nonce,5'd0,bytes};
     else if(cbc_phase==1) cipher_input<=mac^128'h00010000000000000000000000000000;
     else cipher_input<=mac^block_data;
     cipher_start<=1;state<=CBC_WAIT;
    end
    CBC_WAIT:if(cipher_done) begin
     mac<=cipher_output;
     if(cbc_phase==0) begin cbc_phase<=1;state<=CBC_START;end
     else if(cbc_phase==1 && bytes!=0) begin cbc_phase<=2;block_index<=0;word_index<=0;block_data<=0;state<=CBC_READ;end
     else if(cbc_phase==2 && block_index+1<block_count) begin block_index<=block_index+1'b1;word_index<=0;block_data<=0;state<=CBC_READ;end
     else begin
      mic_value<=swap(cipher_output[127:96]^s0);
      if(dec) state<=TAG_READ;
      else if(enc && bytes!=0 && !ctr_finished) begin block_index<=0;state<=CTR_START;end
      else begin tag_byte<=0;state<=TAG_WRITE;end
     end
    end
    CBC_READ:state<=CBC_Q;
    CBC_Q:begin
     block_data[127-word_index*32-:32]<=swap(padded(ram_q,{block_index,4'd0}+{12'd0,word_index,2'd0},bytes));
     if(word_index==3) state<=CBC_START;
     else begin word_index<=word_index+1'b1;state<=CBC_READ;end
    end
    TAG_READ:state<=TAG_Q;
    TAG_Q:begin expected0<=ram_q;state<=TAG_READ2;end
    TAG_READ2:state<=TAG_Q2;
    TAG_Q2:begin
     expected_words={ram_q,expected0};
     mic_ok<=((expected_words>>(bytes[1:0]*8)) & 64'hffffffff)=={32'd0,mic_value};state<=FINISH;
    end
    TAG_WRITE:begin
     if(tag_byte==3) begin mic_ok<=1;state<=FINISH;end
     else tag_byte<=tag_byte+1'b1;
    end
    FINISH:begin busy<=0;done<=1;if(!auth) mic_ok<=0;state<=IDLE;end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
`default_nettype wire
