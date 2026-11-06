`default_nettype none
// SLE 9.4 random-identifier resolution: select IRK ID, calculate CMAC and
// compare the low 16 hash bits. HMAC-SM3 is explicitly not advertised.
module rw_ble_ral_search_engine(
 input wire clk,rst_n,start,abort,algorithm,freeze,
 input wire [15:0] wanted_irk_id,wanted_hash,
 input wire [127:0] random_message,
 input wire [4:0] random_bytes,
 input wire entry_valid,entry_last,
 input wire [15:0] entry_irk_id,entry_tag,
 input wire [127:0] entry_key,
 output wire entry_ready,
 output reg busy,result_valid,matched,error,
 output reg [15:0] result_tag,
 input wire result_ready
);
 reg [2:0] state;
 reg [15:0] irk_id,hash,tag;
 reg [127:0] msg,key;
 reg [4:0] n;
 reg alg,last,go,abort_pending;
 wire cmac_busy,cmac_done,cmac_error;
 wire [127:0] cmac_result;
 assign entry_ready=state==1;
 sle_cmac cmac(.clk(clk),.rst_n(rst_n),.start(go),.algorithm(alg),.key(key),.message(msg),.message_bytes(n),
  .busy(cmac_busy),.done(cmac_done),.error(cmac_error),.result(cmac_result));
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin state<=0;busy<=0;result_valid<=0;matched<=0;error<=0;result_tag<=0;irk_id<=0;hash<=0;tag<=0;msg<=0;key<=0;n<=0;alg<=0;last<=0;go<=0;abort_pending<=0;end
  else begin
   go<=0;
   if(result_valid&&result_ready) result_valid<=0;
   case(state)
    0:if(start&&!result_valid&&!(freeze===1'b1)) begin busy<=1;matched<=0;error<=0;result_tag<=0;irk_id<=wanted_irk_id;hash<=wanted_hash;msg<=random_message;n<=random_bytes;alg<=algorithm;state<=1;end
    1:if(entry_valid) begin
     if(entry_irk_id==irk_id) begin key<=entry_key;tag<=entry_tag;last<=entry_last;state<=2;end
     else if(entry_last) begin busy<=0;result_valid<=1;state<=0;end
    end
    2:begin go<=1;state<=3;end
    3:if(cmac_done) begin
     if(cmac_error || cmac_result[15:0]==hash || last) begin
      busy<=0;result_valid<=1;error<=cmac_error;matched<=!cmac_error&&cmac_result[15:0]==hash;
      result_tag<=cmac_result[15:0]==hash?tag:16'd0;state<=0;
     end else state<=1;
    end
    default:state<=0;
   endcase
   if(abort)abort_pending<=1;
   if((abort||abort_pending)&&!cmac_busy) begin state<=0;busy<=0;result_valid<=0;abort_pending<=0;end
  end
 end
endmodule
`default_nettype wire
