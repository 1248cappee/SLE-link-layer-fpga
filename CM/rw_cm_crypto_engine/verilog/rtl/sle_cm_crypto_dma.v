`default_nettype none
// Software CCM command, 32-byte object in the first 32KiB (2-byte pointer).
// +0 src_ptr16 | payload_length11<<16; +4 dst_ptr16 | capacity11<<16;
// +8..+20 thirteen nonce bytes, first byte at +8[7:0]; +24 result; +28 zero.
// mode[0]=SM4, [1]=decrypt, [2]=authenticate-only. Key is in CM key registers.
// The scheduler port is exclusively owned until the final result write ACK.
module sle_cm_crypto_dma #(parameter integer EM_BYTES=131072)(
 input wire clk,rst_n,start,
 input wire [15:0] command_ptr,
 input wire [2:0] mode,
 input wire [127:0] key,
 output reg busy,done,error,
 output reg [31:0] result,
 output reg em_req,em_write,
 output reg [16:0] em_addr,
 output reg [31:0] em_wdata,
 output reg [3:0] em_be,
 input wire em_ack,em_fault,
 input wire [31:0] em_rdata
);
 reg [4:0] state;
 reg [31:0] command[0:7];
 reg [16:0] base,source,destination;
 reg [2:0] index,operation;
 reg [9:0] word_index,word_count;
 reg [10:0] length,output_length;
 reg [127:0] saved_key;
 reg [103:0] nonce;
 reg store_we,read_req,go;
 reg [31:0] store_data;
 reg [3:0] store_be;
 wire read_valid,crypto_busy,crypto_done,crypto_error,mic_ok;
 wire [31:0] read_data,mic;
 integer i;
 rw_cm_crypto_engine engine(.clk(clk),.rst_n(rst_n),.store_we(store_we),.store_addr(word_index[8:0]),
  .store_data(store_data),.store_be(store_be),.read_req(read_req),.read_addr(word_index[8:0]),
  .read_valid(read_valid),.read_data(read_data),.start(go),.algorithm(operation[0]),
  .decrypt(operation[1]),.encrypt_payload(!operation[2]),.mic_enable(1'b1),.key(saved_key),.nonce(nonce),
  .length(length),.busy(crypto_busy),.done(crypto_done),.error(crypto_error),.mic_ok(mic_ok),.mic_value(mic));
 task failed;
 input [7:0] why;
 begin error<=1;result<={16'd0,why,why==4?8'h07:8'h03};state<=15;end
 endtask
 function [3:0] lanes;
 input [11:0] count;
 begin lanes=count>=4?4'hf:(count==3?4'h7:(count==2?4'h3:(count==1?4'h1:4'h0)));end
 endfunction
 always @(posedge clk)begin
  if(!rst_n)begin
   state<=0;busy<=0;done<=0;error<=0;result<=0;em_req<=0;em_write<=0;em_addr<=0;em_wdata<=0;em_be<=0;
   base<=0;source<=0;destination<=0;index<=0;operation<=0;word_index<=0;word_count<=0;length<=0;output_length<=0;
   saved_key<=0;nonce<=0;store_we<=0;read_req<=0;go<=0;store_data<=0;store_be<=0;
   for(i=0;i<8;i=i+1)command[i]<=0;
  end else begin
   done<=0;store_we<=0;read_req<=0;go<=0;
   case(state)
    0:if(start)begin
     busy<=1;error<=0;result<=0;base<={command_ptr,1'b0};index<=0;operation<=mode;saved_key<=key;
     if(command_ptr==0||command_ptr[0]||command_ptr>=16369)begin
      error<=1;result<=32'h00000103;state<=17;
     end else state<=1;
    end
    1:begin em_req<=1;em_write<=0;em_addr<=base+{12'd0,index,2'd0};em_be<=15;state<=2;end
    2:if(em_ack)begin
     em_req<=0;
     if(em_fault)failed(2);
     else begin command[index]<=em_rdata;if(index==7)state<=3;else begin index<=index+1'b1;state<=1;end end
    end
    3:begin
     source<={command[0][15:0],1'b0};destination<={command[1][15:0],1'b0};length<=command[0][26:16];
     output_length<=command[0][26:16]+(operation[1]?0:11'd4);
     word_count<=({1'b0,command[0][26:16]}+(operation[1]?12'd4:12'd0)+3)>>2;word_index<=0;
     for(i=0;i<13;i=i+1)nonce[103-i*8-:8]<=command[2+i/4][(i%4)*8+:8];
     if(command[0][31:27]!=0||command[1][31:27]!=0||command[0][26:16]>2043||
        command[0][15:0]==0||command[1][15:0]==0||command[0][0]||command[1][0]||
        command[1][26:16]<command[0][26:16]+(operation[1]?0:4)||command[5][31:8]!=0||command[7]!=0||
        ({command[0][15:0],1'b0}+command[0][26:16]+(operation[1]?4:0))>EM_BYTES||
        ({command[1][15:0],1'b0}+command[1][26:16])>EM_BYTES)failed(3);
     else if(command[0][26:16]==0&&!operation[1])state<=7;
     else state<=4;
    end
    4:begin em_req<=1;em_write<=0;em_addr<=source+{5'd0,word_index,2'd0};em_be<=15;state<=5;end
    5:if(em_ack)begin
     em_req<=0;
     if(em_fault)failed(2);
     else begin store_we<=1;store_data<=em_rdata;store_be<=15;state<=6;end
    end
    6:if(word_index+1==word_count)begin word_index<=0;state<=7;end
      else begin word_index<=word_index+1'b1;state<=4;end
    7:begin go<=1;state<=8;end
    8:if(crypto_done)begin
     if(crypto_error||(operation[1]&&!mic_ok))failed(4);
     else begin
      result<={13'd0,output_length,8'h1d};
      word_index<=0;word_count<=({1'b0,output_length}+3)>>2;
      state<=output_length==0?15:9;
     end
    end
    9:begin read_req<=1;state<=10;end
    10:if(read_valid)begin
     em_wdata<=read_data;em_addr<=destination+{5'd0,word_index,2'd0};
     em_be<=lanes({1'b0,output_length}-{word_index,2'b00});state<=11;
    end
    11:begin em_req<=1;em_write<=1;state<=12;end
    12:if(em_ack)begin
     em_req<=0;
     if(em_fault)failed(2);
     else if(word_index+1==word_count)state<=15;
     else begin word_index<=word_index+1'b1;state<=9;end
    end
    15:begin em_req<=1;em_write<=1;em_addr<=base+24;em_wdata<=result;em_be<=15;state<=16;end
    16:if(em_ack)begin em_req<=0;if(em_fault)begin error<=1;result<=32'h00000207;end state<=17;end
    17:begin busy<=0;done<=1;saved_key<=0;nonce<=0;state<=0;end
    default:state<=0;
   endcase
  end
 end
endmodule
`default_nettype wire
