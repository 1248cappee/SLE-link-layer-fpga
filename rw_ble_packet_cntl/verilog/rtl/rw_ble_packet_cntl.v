`include "sle_defs.vh"
`default_nettype none
module rw_ble_packet_cntl #(parameter integer EM_BYTES=131072)(
 input wire clk,rst_n,tick_fine,
 input wire [29:0] now_slot,
 input wire [9:0] now_fine,
 input wire job_valid,
 output wire job_ready,
 input wire [3:0] job_index,
 input wire [13:0] job_csptr,
 input wire [2:0] job_mode,
 input wire [29:0] job_slot,
 input wire [9:0] job_fine,
 input wire [1023:0] context_data,
 input wire [127:0] cm_context,
 input wire [9:0] day_count,
 input wire day_valid,
 input wire [15:0] time_generation,
 input wire hop_error,
 input wire [6:0] hop_channel,
 input wire cs_layout_valid,radio_grant,scan_valid,
 input wire [6:0] scan_channel,
 input wire [31:0] event_elapsed,
 input wire control_valid,
 input wire [63:0] native_control_bits,
 output wire [63:0] control_template,
 output wire [1167:0] cs_image,
 output wire phase_is_tx,
 input wire cancel,requeue,start_ack,coex_revoked,
 output wire idle,
 output reg running,started,done,abandoned,
 output reg [3:0] active_index,
 output reg [29:0] actual_start_slot,
 output reg [9:0] actual_start_fine,
 output reg [2:0] final_status,
 output reg [7:0] final_reason,
 output reg event_valid,
 input wire event_ready,
 output reg [71:0] event_data,
 output reg [4:0] error_set,
 output reg em_req,em_write,
 output reg [16:0] em_addr,
 output reg [31:0] em_wdata,
 output reg [3:0] em_be,
 input wire em_ack,em_fault,
 input wire [31:0] em_rdata,
 // Native TX PHY interface, unchanged field widths.
 output reg tx_cfg_valid,
 input wire tx_cfg_ready,
 output wire [2:0] tx_frame_type,
 output wire [4:0] tx_ctrl_format,
 output wire [3:0] tx_mcs,
 output wire [6:0] tx_channel,
 output wire [15:0] tx_payload_bytes,
 output wire [1:0] tx_crc_mode,
 output wire [31:0] tx_crc_seed,
 output wire [23:0] tx_cb_seed,tx_llid,
 output wire [63:0] tx_ctrl_bits,
 output wire [6:0] tx_ctrl_len,
 output wire tx_whitening,tx_feedback_cbg,tx_broadcast,
 output wire [1:0] tx_pilot,tx_bandwidth,
 output wire [2:0] tx_mseq_id,
 output reg [31:0] tx_data,
 output reg [3:0] tx_keep,
 output reg tx_valid,tx_last,
 input wire tx_ready,tx_error,
 // Transport milestones are deliberately NOT connected to coding_done.
 output reg tx_launch,tx_stop,
 input wire tx_prepared,tx_air_started,tx_air_done,tx_quiescent,
 input wire [29:0] tx_start_slot,
 input wire [9:0] tx_start_fine,
 // Native RX mailbox bus.
 output reg rx_req,rx_write,
 output reg [7:0] rx_addr,
 output reg [31:0] rx_wdata,
 input wire rx_rvalid,rx_irq,
 input wire [31:0] rx_rdata,
 output reg rx_stop,
 input wire rx_window_started,rx_drain_done,rx_sync_valid,
 input wire [29:0] rx_sync_slot,
 input wire [9:0] rx_sync_fine,
 input wire [31:0] phy_caps
);
 localparam IDLE=0,CS_REQ=1,CS_WAIT=2,CHECK=3,DESC_REQ=4,DESC_WAIT=5,META_REQ=6,META_WAIT=7,
  META_CHECK=8,LOAD_REQ=9,LOAD_WAIT=10,LOAD_STORE=11,CRYPTO_START=12,CRYPTO_WAIT=13,
  TX_CFG=14,TX_READ=15,TX_Q=16,TX_STREAM=17,WAIT_TARGET=18,TX_LAUNCH=19,TX_WAIT_START=20,
  WAIT_START_ACK=21,TX_AIR=22,RX_CONFIG=23,RX_RUN=24,RX_POLL=25,RX_POLL_WAIT=26,
  RX_HEAD=27,RX_HEAD_WAIT=28,RX_DATA=29,RX_DATA_WAIT=30,RX_STORE=31,RX_ACK=32,
  RX_CRYPTO=33,RX_WRITE_READ=34,RX_WRITE_Q=35,RX_WRITE=36,RX_WRITE_WAIT=37,
  WRITEBACK=38,WRITEBACK_WAIT=39,PACKET_EVENT=40,NEXT_PACKET=41,GAP=42,STOP=43,FINISH=44,
  RX_ARM=45,RAW_REQUEST=46,RAW_WAIT=47,RX_MAILBOX_CLOSE=48;
 reg [5:0] state,after_start,return_state;
 reg [1023:0] cfg;
 reg nonce_by_time,nonce_valid;
 reg [9:0] packet_day;
 reg [29:0] target_slot;
 reg [9:0] target_fine;
 reg [13:0] csptr,desc_ptr,next_desc,first_tx,first_rx,tx_cursor,rx_cursor;
 reg [15:0] tx_meta_cursor,rx_meta_cursor;
 reg gap_finish,tx_touched,rx_touched,requeue_pending;
 reg [15:0] meta_ptr,next_meta,first_tx_meta,first_rx_meta,data_ptr;
 reg [2:0] mode;
 reg phase,cont,tx_irq_en,rx_irq_en,cancel_latched;
 reg [15:0] cs_words[0:72];
 reg [15:0] desc_words[0:13];
 reg [31:0] meta_words[0:3];
 reg [6:0] cs_index;
 reg [3:0] desc_index;
 reg [1:0] meta_index;
 reg [10:0] payload_len,wire_len,capacity;
 reg [15:0] min_ticks,max_ticks,rx_ticks,rx_max_ticks;
 wire [31:0] elapsed=event_elapsed;
 reg [31:0] packet_elapsed,gap_elapsed,airtime;
 reg [9:0] word_index,word_count;
 reg [16:0] byte_address;
 reg [31:0] load_word,rx_header,rx_lengths,rx_details;
 reg [15:0] previous_half;
 reg tx_unaligned;
 reg [3:0] writeback_index;
 reg [15:0] status_word;
 reg [31:0] outcome;
 reg crc_ok,mic_applicable,mic_pass,deliver,sync_seen,ram_written;
 reg [29:0] sync_slot;
 reg [9:0] sync_fine;
 reg [29:0] packet_stamp_slot;
 reg [9:0] packet_stamp_fine;
 reg [7:0] rx_config_index;
 reg [10:0] chain_steps;
 reg [38:0] tx_security_counter,rx_security_counter;
 reg tx_counter_exhausted,rx_counter_exhausted;
 reg raw_write;
 reg [16:0] raw_addr;
 reg [31:0] raw_data;
 reg [3:0] raw_be;
 reg store_we,buffer_read,crypto_start;
 reg [8:0] store_addr,buffer_addr;
 reg [31:0] store_data;
 reg [3:0] store_be;
 wire buffer_valid;
 wire [31:0] buffer_data;
 wire crypto_busy,crypto_done,crypto_error,crypto_mic_ok;
 wire [31:0] crypto_mic;
 reg stream_start;
 reg [8:0] stream_output_index;
 wire stream_ready,stream_valid,stream_last,stream_busy,stream_done,stream_error;
 wire [31:0] stream_data;
 wire [3:0] stream_keep;
 wire stream_sink_ready=(!tx_valid||tx_ready)&&state!=STOP&&state!=FINISH&&state!=IDLE;
 wire [1:0] security=cfg[16+:2]; // 0 plain,1 AES-CCM,2 SM4-CCM,3 invalid
 wire auth_only=cfg[18];
 wire is_tx,sequence_end,repeat_sequence,valid_mode;
 wire [127:0] key={cfg[15*32+:32],cfg[14*32+:32],cfg[13*32+:32],cfg[12*32+:32]};
 wire [63:0] iv={cfg[17*32+:32],(cfg[16*32+:32]^(tx_frame_type<3?cfg[20*32+:32]:{8'd0,tx_llid}))};
 wire [29:0] nonce_time_slot=is_tx?target_slot:sync_slot;
 wire [9:0] nonce_time_day=packet_day+((!is_tx&&sync_slot<target_slot)?10'd1:10'd0);
 wire [39:0] counter_direction=nonce_by_time?{nonce_time_day,nonce_time_slot}:
                      (is_tx?{cfg[19*32+7],tx_security_counter}:{cfg[11*32+7],rx_security_counter});
 // Counter occupies five little-endian octets, IV follows eight octets.
 wire [103:0] nonce={counter_direction[7:0],counter_direction[15:8],counter_direction[23:16],
  counter_direction[31:24],counter_direction[39:32],iv[7:0],iv[15:8],iv[23:16],iv[31:24],iv[39:32],iv[47:40],iv[55:48],iv[63:56]};
 wire [29:0] time_delta=now_slot-target_slot;
 wire target_reached=(!time_delta[29]&&time_delta!=0)||(time_delta==0&&now_fine>=target_fine);
 wire window_expired=running && elapsed>=max_ticks;
 wire receive_expired=(rx_ticks!=0 && packet_elapsed>=rx_ticks)||(rx_max_ticks!=0&&packet_elapsed>=rx_max_ticks);
 assign job_ready=state==IDLE;
 assign idle=state==IDLE;
 assign phase_is_tx=is_tx;
 genvar cs_word;
 generate for(cs_word=0;cs_word<73;cs_word=cs_word+1)begin:cs_export
  assign cs_image[cs_word*16+:16]=cs_words[cs_word];
 end endgenerate
 assign tx_frame_type=cfg[2:0];assign tx_ctrl_format=cfg[7:3];assign tx_mcs=cfg[11:8];
 assign tx_channel=cfg[22*32+:7];assign tx_payload_bytes={5'd0,wire_len};
 assign tx_crc_mode=cfg[13:12];assign tx_crc_seed=cfg[2*32+:32];assign tx_cb_seed=cfg[3*32+:24];
 assign tx_llid=cfg[1*32+:24];
 assign control_template={cfg[5*32+:32],cfg[4*32+:32]};assign tx_ctrl_bits=native_control_bits;assign tx_ctrl_len=cfg[6*32+:7];
 assign tx_whitening=cfg[6*32+8];assign tx_feedback_cbg=cfg[6*32+9];assign tx_pilot=cfg[6*32+10+:2];
 assign tx_broadcast=cfg[6*32+12];assign tx_bandwidth=cfg[14+:2];assign tx_mseq_id=cfg[6*32+13+:3];
 rw_ble_packet_cntl_main_fsm policy(.mode(mode),.phase(phase),.cont(cont),.cancelled(cancel_latched),
  .window_expired(window_expired),.chain_available(next_desc!=0),.is_tx(is_tx),.sequence_end(sequence_end),.repeat_sequence(repeat_sequence),.valid_mode(valid_mode));
 rw_cm_crypto_engine buffer_crypto(.clk(clk),.rst_n(rst_n),.store_we(store_we),.store_addr(store_addr),
  .store_data(store_data),.store_be(store_be),.read_req(buffer_read),.read_addr(buffer_addr),.read_valid(buffer_valid),.read_data(buffer_data),
  .start(crypto_start),.algorithm(security==2),.decrypt(!is_tx),.encrypt_payload(!auth_only),.mic_enable(security!=0),
  .key(key),.nonce(nonce),.length(payload_len),.busy(crypto_busy),.done(crypto_done),.error(crypto_error),.mic_ok(crypto_mic_ok),.mic_value(crypto_mic));
 wire stream_rst_n;
 rw_cm_reset_sync stream_reset(.clk(clk),.async_n(rst_n),.hold(tx_stop),.reset_n(stream_rst_n));
 sle_ccm_stream_tx stream_crypto(.clk(clk),.rst_n(stream_rst_n),.start(stream_start),.algorithm(security==2),.auth_only(auth_only),
  .key(key),.nonce(nonce),.length(payload_len),.s_data(load_word),.s_valid(state==LOAD_STORE&&is_tx&&security!=0),.s_ready(stream_ready),
  .m_data(stream_data),.m_keep(stream_keep),.m_valid(stream_valid),.m_last(stream_last),.m_ready(stream_sink_ready),
  .busy(stream_busy),.done(stream_done),.error(stream_error));
 integer i;
 reg [15:0] half_value;
 reg [31:0] control_word;
 reg [10:0] remaining;
 function [3:0] keep_for;
  input [10:0] n;
  begin case(n) 0:keep_for=0;1:keep_for=1;2:keep_for=3;3:keep_for=7;default:keep_for=15;endcase end
 endfunction
 task finish_error;
  input [7:0] reason;
  begin final_status<=`SLE_ERROR;final_reason<=reason;state<=STOP;if(reason==`SLE_BUS_FAULT) error_set[3]<=1;else error_set[0]<=1;end
 endtask
 // Logical halfword read/write helper; the physical EM port remains 32 bit.
 task issue_half;
  input wr;
  input [16:0] address;
  input [15:0] value;
  input [5:0] resume;
  begin raw_write<=wr;raw_addr<={address[16:2],2'b00};raw_data<=address[1]?{value,16'd0}:{16'd0,value};
   raw_be<=address[1]?4'b1100:4'b0011;byte_address<=address;return_state<=resume;state<=RAW_REQUEST;end
 endtask
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   state<=IDLE;after_start<=0;return_state<=0;cfg<=0;target_slot<=0;target_fine<=0;csptr<=0;desc_ptr<=0;next_desc<=0;
   nonce_by_time<=0;nonce_valid<=0;packet_day<=0;
   first_tx<=0;first_rx<=0;meta_ptr<=0;next_meta<=0;first_tx_meta<=0;first_rx_meta<=0;data_ptr<=0;
   tx_cursor<=0;rx_cursor<=0;tx_meta_cursor<=0;rx_meta_cursor<=0;gap_finish<=0;tx_touched<=0;rx_touched<=0;requeue_pending<=0;tx_stop<=0;
   mode<=0;phase<=0;cont<=0;tx_irq_en<=0;rx_irq_en<=0;cancel_latched<=0;running<=0;started<=0;done<=0;abandoned<=0;active_index<=0;
   actual_start_slot<=0;actual_start_fine<=0;final_status<=`SLE_DONE;final_reason<=0;event_valid<=0;event_data<=0;error_set<=0;
   em_req<=0;em_write<=0;em_addr<=0;em_wdata<=0;em_be<=0;tx_cfg_valid<=0;tx_data<=0;tx_keep<=0;tx_valid<=0;tx_last<=0;tx_launch<=0;
   rx_req<=0;rx_write<=0;rx_addr<=0;rx_wdata<=0;rx_stop<=0;cs_index<=0;desc_index<=0;meta_index<=0;
   payload_len<=0;wire_len<=0;capacity<=0;min_ticks<=0;max_ticks<=0;rx_ticks<=0;rx_max_ticks<=0;packet_elapsed<=0;gap_elapsed<=0;airtime<=0;
   word_index<=0;word_count<=0;byte_address<=0;load_word<=0;previous_half<=0;tx_unaligned<=0;writeback_index<=0;status_word<=0;outcome<=0;
   crc_ok<=0;mic_applicable<=0;mic_pass<=0;deliver<=0;sync_seen<=0;sync_slot<=0;sync_fine<=0;ram_written<=0;
   packet_stamp_slot<=0;packet_stamp_fine<=0;rx_config_index<=0;chain_steps<=0;raw_write<=0;raw_addr<=0;raw_data<=0;raw_be<=0;
   store_we<=0;store_addr<=0;store_data<=0;store_be<=0;buffer_read<=0;buffer_addr<=0;crypto_start<=0;rx_header<=0;rx_lengths<=0;rx_details<=0;
   stream_start<=0;stream_output_index<=0;
   tx_security_counter<=0;rx_security_counter<=0;tx_counter_exhausted<=0;rx_counter_exhausted<=0;
   for(i=0;i<73;i=i+1) cs_words[i]<=0;
   for(i=0;i<14;i=i+1) desc_words[i]<=0;
   for(i=0;i<4;i=i+1) meta_words[i]<=0;
  end else begin
   started<=0;done<=0;abandoned<=0;error_set<=0;store_we<=0;buffer_read<=0;crypto_start<=0;stream_start<=0;tx_launch<=0;rx_req<=0;
   if(cancel) cancel_latched<=1;
   if(running && tick_fine) begin packet_elapsed<=packet_elapsed+1'b1;gap_elapsed<=gap_elapsed+1'b1;end
   if(rx_sync_valid && running && !is_tx && !sync_seen) begin
    if(rx_sync_fine>249)error_set[1]<=1;
    else begin sync_seen<=1;sync_slot<=rx_sync_slot;sync_fine<=rx_sync_fine;
     if(nonce_by_time&&(&packet_day)&&rx_sync_slot<target_slot)nonce_valid<=0;
    end
   end
   case(state)
    IDLE:if(job_valid) begin
     active_index<=job_index;csptr<=job_csptr;mode<=job_mode;target_slot<=job_slot;target_fine<=job_fine;cfg<=context_data;
     nonce_by_time<=cm_context[8]===1'b1;
     packet_day<=day_count+((job_slot<now_slot&&!((job_slot-now_slot)&30'h20000000))?10'd1:10'd0);
     nonce_valid<=!(cm_context[8]===1'b1) ||
       (day_valid && cm_context[96+:16]==time_generation &&
        !((&day_count)&&job_slot<now_slot));
     phase<=0;cancel_latched<=0;running<=0;packet_elapsed<=0;final_status<=`SLE_DONE;final_reason<=0;
     tx_security_counter<={context_data[19*32+:7],context_data[18*32+:32]};
     rx_security_counter<={context_data[11*32+:7],context_data[10*32+:32]};
     tx_counter_exhausted<=0;rx_counter_exhausted<=0;
     tx_touched<=0;rx_touched<=0;gap_finish<=0;requeue_pending<=0;tx_stop<=0;
     cs_index<=0;chain_steps<=0;state<=CS_REQ;
    end
    CS_REQ:issue_half(0,({3'd0,csptr}<<1)+{9'd0,cs_index,1'b0},0,CS_WAIT);
    CS_WAIT:begin cs_words[cs_index]<=half_value;if(cs_index==72) state<=CHECK;else begin cs_index<=cs_index+1'b1;state<=CS_REQ;end end
    CHECK:begin
     first_tx<=cs_words[18][13:0];first_rx<=cs_words[17][13:0];cont<=cs_words[0][3];tx_irq_en<=cs_words[0][4];rx_irq_en<=cs_words[0][5];
     min_ticks<=cs_words[23];max_ticks<=cs_words[24];rx_ticks<=cs_words[15];rx_max_ticks<=cs_words[29];
     first_tx_meta<=cfg[8*32+:16];first_rx_meta<=cfg[9*32+:16];
     tx_cursor<=cs_words[18][13:0];rx_cursor<=cs_words[17][13:0];tx_meta_cursor<=cfg[8*32+:16];rx_meta_cursor<=cfg[9*32+:16];
     if(cfg[25]) cfg[22*32+:32]<={25'd0,hop_channel};
     if(cfg[26]&&scan_valid) cfg[22*32+:32]<={25'd0,scan_channel};
     desc_ptr<=is_tx?cs_words[18][13:0]:cs_words[17][13:0];meta_ptr<=is_tx?cfg[8*32+:16]:cfg[9*32+:16];
     if(!valid_mode || !cs_layout_valid || cs_words[0][2:0]!=mode || cs_words[24]==0 || cs_words[23]>cs_words[24] ||
       (security!=0&&(!nonce_valid || (nonce_by_time&&(mode>1||cs_words[0][3])))) ||
       tx_frame_type<1 || tx_frame_type>4 || tx_mcs>12 || tx_mseq_id>5 || security==3 ||
       (!cfg[25]&&!cfg[26]&&cfg[22*32+7+:25]!=0) || (cfg[25]&&hop_error) || (cfg[26]&&!scan_valid) ||
       (cfg[25]&&cfg[26]) || (phy_caps & 32'hf)!=32'hf) finish_error(`SLE_BAD_DESC);
     else if((is_tx?cs_words[18][13:0]:cs_words[17][13:0])==0) begin
      if(is_tx)finish_error(`SLE_BAD_DESC);else begin final_reason<=`SLE_NO_BUFFER;state<=FINISH;end
     end
     else begin desc_index<=0;state<=DESC_REQ;end
    end
    DESC_REQ:begin
     if(desc_ptr==0 || (({3'd0,desc_ptr}<<1)+(is_tx?16:28))>EM_BYTES ||
       (({3'd0,desc_ptr}<<1)+(is_tx?16:28))>32768 || chain_steps==2047) finish_error(`SLE_BAD_DESC);
     else issue_half(0,({3'd0,desc_ptr}<<1)+{12'd0,desc_index,1'b0},0,DESC_WAIT);
    end
    DESC_WAIT:begin
     desc_words[desc_index]<=half_value;
     if(desc_index==(is_tx?7:13)) begin
      next_desc<=desc_words[0][13:0];data_ptr<=is_tx?desc_words[2]:desc_words[10];
      if(meta_ptr==0 || (({1'b0,meta_ptr}<<1)+16)>EM_BYTES) finish_error(`SLE_BAD_DESC);
      else begin meta_index<=0;state<=META_REQ;end
     end else begin desc_index<=desc_index+1'b1;state<=DESC_REQ;end
    end
    META_REQ:begin
     if(meta_ptr[0]) finish_error(`SLE_BAD_DESC);
     else begin em_req<=1;em_write<=0;em_be<=15;em_addr<=({1'b0,meta_ptr}<<1)+{13'd0,meta_index,2'd0};state<=META_WAIT;end
    end
    META_WAIT:if(em_ack) begin
     em_req<=0;
     if(em_fault) finish_error(`SLE_BUS_FAULT);
     else begin meta_words[meta_index]<=em_rdata;if(meta_index==3) state<=META_CHECK;else begin meta_index<=meta_index+1'b1;state<=META_REQ;end end
    end
    META_CHECK:begin
     if(cfg[26]&&scan_valid) cfg[22*32+:32]<={25'd0,scan_channel};
     payload_len<=meta_words[1][10:0];capacity<=meta_words[1][26:16];next_meta<=meta_words[0][31:16];airtime<=meta_words[2];
     wire_len<=meta_words[1][10:0]+(security!=0?11'd4:11'd0);
     tx_unaligned<=data_ptr[0];word_index<=0;byte_address<=({1'b0,data_ptr}<<1);chain_steps<=chain_steps+1'b1;
     if(meta_words[0][13:0]!=desc_ptr || meta_words[0][15:14]!=0 || meta_words[1][15:11]!=0 || meta_words[1][31:27]!=0 ||
       (nonce_by_time&&security!=0&&next_desc!=0) || desc_words[0][15] || data_ptr==0 || meta_words[1][26:16]==0 ||
       (security!=0 && (is_tx?tx_counter_exhausted:rx_counter_exhausted)) ||
       (({1'b0,data_ptr}<<1)+meta_words[1][26:16])>EM_BYTES ||
       (is_tx && ({1'b0,meta_words[1][10:0]}+(security!=0?12'd4:0)>meta_words[1][26:16])) ||
       (is_tx && ({1'b0,meta_words[1][10:0]}+(security!=0?12'd4:0)>2047))) finish_error(`SLE_BAD_DESC);
     else if(is_tx) begin
      if(security!=0)begin stream_start<=1;stream_output_index<=0;end
      word_count<=({1'b0,meta_words[1][10:0]}+3)>>2;
      state<=TX_CFG;
     end else begin rx_config_index<=0;state<=RX_CONFIG;sync_seen<=0;end
    end
    LOAD_REQ:begin em_req<=1;em_write<=0;em_be<=15;em_addr<={byte_address[16:2],2'd0}+{5'd0,word_index,2'd0};state<=LOAD_WAIT;end
    LOAD_WAIT:if(em_ack) begin
     em_req<=0;
     if(em_fault) finish_error(`SLE_BUS_FAULT);
     else if(tx_unaligned && word_index==0) begin
      previous_half<=em_rdata[31:16];word_index<=1;
      if(payload_len<=2) begin load_word<={16'd0,em_rdata[31:16]};state<=LOAD_STORE;end
      else state<=LOAD_REQ;
     end
     else begin
      load_word<=tx_unaligned?{em_rdata[15:0],previous_half}:em_rdata;previous_half<=em_rdata[31:16];state<=LOAD_STORE;
     end
    end
    LOAD_STORE:begin
     if(security==0&&!tx_valid)begin
      tx_data<=load_word;remaining=payload_len-((tx_unaligned?word_index-1'b1:word_index)*4);
      tx_keep<=keep_for(remaining);tx_last<=remaining<=4;tx_valid<=1;
     end
     if((security!=0&&stream_ready)||(security==0&&tx_valid&&tx_ready))begin
      if(security==0)tx_valid<=0;
      if((tx_unaligned?word_index:word_index+1)>=word_count) begin
       word_index<=0;if(security!=0) state<=CRYPTO_WAIT;else state<=WAIT_TARGET;
      end else if(tx_unaligned && payload_len-({word_index,2'd0})<=2) begin
       word_index<=word_index+1'b1;load_word<={16'd0,previous_half};state<=LOAD_STORE;
      end else begin word_index<=word_index+1'b1;state<=LOAD_REQ;end
     end
    end
    CRYPTO_START:begin crypto_start<=1;state<=CRYPTO_WAIT;end
    CRYPTO_WAIT:if(stream_done) begin if(stream_error) finish_error(`SLE_BAD_DESC);else state<=WAIT_TARGET;end
    TX_CFG:begin
     if(!control_valid)finish_error(`SLE_BAD_DESC);
     else if(running && (window_expired || airtime==0 || elapsed+airtime>max_ticks)) begin final_reason<=`SLE_WINDOW_END;state<=STOP;end
     else if(!running && (airtime==0 || airtime>max_ticks)) finish_error(`SLE_BAD_DESC);
     else begin tx_cfg_valid<=1;if(tx_cfg_ready && tx_cfg_valid) begin
      tx_touched<=1;tx_cfg_valid<=0;word_index<=0;word_count<=({1'b0,payload_len}+3)>>2;
      state<=payload_len==0?(security!=0?CRYPTO_WAIT:WAIT_TARGET):LOAD_REQ;
     end end
    end
    TX_READ:begin buffer_read<=1;buffer_addr<=word_index[8:0];state<=TX_Q;end
    TX_Q:if(buffer_valid) begin
     tx_data<=buffer_data;remaining=wire_len-{word_index,2'd0};tx_keep<=keep_for(remaining);tx_last<=remaining<=4;tx_valid<=1;state<=TX_STREAM;
    end
    TX_STREAM:if(tx_valid&&tx_ready) begin
     tx_valid<=0;if(word_index+1==word_count) state<=WAIT_TARGET;else begin word_index<=word_index+1'b1;state<=TX_READ;end
    end
    WAIT_TARGET:begin
     if(cancel_latched) begin final_status<=`SLE_CANCELLED;final_reason<=`SLE_SW_CANCEL;state<=STOP;end
     else if(target_reached || running) begin
      if(!radio_grant)begin final_status<=running?`SLE_DONE:`SLE_SKIPPED;final_reason<=`SLE_CONFLICT;state<=STOP;end
      else if(!is_tx) begin state<=RX_ARM;end
      else if(running && elapsed+airtime>max_ticks) begin final_reason<=`SLE_WINDOW_END;state<=STOP;end
      else if(tx_prepared) begin tx_launch<=1;state<=TX_WAIT_START;end
      else if(target_reached && !running && (time_delta!=0 || now_fine!=target_fine)) finish_error(`SLE_LATE);
     end
    end
    TX_WAIT_START:if(tx_air_started) begin
     packet_elapsed<=0;packet_stamp_slot<=tx_start_slot;packet_stamp_fine<=tx_start_fine;
     if(tx_start_fine>249)begin error_set[1]<=1;final_status<=`SLE_ERROR;final_reason<=`SLE_BAD_DESC;state<=STOP;end
     else if(!running) begin running<=1;started<=1;actual_start_slot<=tx_start_slot;actual_start_fine<=tx_start_fine;after_start<=TX_AIR;state<=WAIT_START_ACK;end
     else state<=TX_AIR;
    end
    WAIT_START_ACK:if(start_ack) state<=after_start;
    TX_AIR:if(tx_air_done) begin
     status_word<=16'h8000|{2'd0,next_desc};writeback_index<=0;outcome<=32'h00000011;packet_stamp_slot<=now_slot;packet_stamp_fine<=now_fine;state<=WRITEBACK;
    end
    RX_CONFIG:begin
     rx_touched<=1;
     // Eight immutable writes per RX event. RX-specific front-end defaults
     // are configured by the integration profile, not guessed by the MAC.
     rx_req<=1;rx_write<=1;
     case(rx_config_index)
      0:begin rx_addr<=8'h04;rx_wdata<={tx_mseq_id,1'b0,tx_whitening,1'b1,2'b00,4'd4,tx_bandwidth,tx_feedback_cbg,tx_crc_mode,tx_channel,tx_ctrl_format,tx_frame_type};end
      1:begin rx_addr<=8'h14;rx_wdata<=tx_crc_seed;end
      2:begin rx_addr<=8'h18;rx_wdata<={8'd0,tx_cb_seed};end
      3:begin rx_addr<=8'h1c;rx_wdata<={8'd0,tx_llid};end
      4:begin rx_addr<=8'h24;rx_wdata<={30'd0,tx_pilot};end
      5:begin rx_addr<=8'h00;rx_wdata<=32'h00000208;end // FRAME_END, receiver off
      6:begin rx_addr<=8'h3c;rx_wdata<=1;end // discard stale mailbox
      default:begin rx_addr<=8'h00;rx_wdata<=32'h80000204;end // clear + IRQ W1C, receiver off
     endcase
     if(rx_config_index==7) begin rx_config_index<=0;state<=WAIT_TARGET;end
     else rx_config_index<=rx_config_index+1'b1;
    end
    RX_ARM:begin rx_req<=1;rx_write<=1;rx_addr<=0;rx_wdata<=32'h00000203;state<=RX_RUN;end
    RX_RUN:if(rx_window_started) begin
     packet_elapsed<=0;
     if(!running) begin running<=1;started<=1;actual_start_slot<=now_slot;actual_start_fine<=now_fine;after_start<=RX_POLL;state<=WAIT_START_ACK;end
     else state<=RX_POLL;
    end
    RX_POLL:begin
     if(cancel_latched||window_expired||receive_expired) begin final_status<=cancel_latched?`SLE_CANCELLED:`SLE_DONE;final_reason<=cancel_latched?`SLE_SW_CANCEL:`SLE_WINDOW_END;state<=STOP;end
     else if(rx_irq) begin rx_req<=1;rx_write<=0;rx_addr<=8'hd0;state<=RX_POLL_WAIT;end
    end
    RX_POLL_WAIT:if(rx_rvalid) begin
     if(!rx_rdata[3]) begin rx_req<=1;rx_write<=1;rx_addr<=0;rx_wdata<=32'h80000201;state<=RX_POLL;end
     else begin rx_header<=rx_rdata;rx_config_index<=0;state<=RX_MAILBOX_CLOSE;end
    end
    RX_MAILBOX_CLOSE:begin
     // Freeze the completed frame's mailbox while copying/authenticating it;
     // do not leave an unserviced receive window open during the DMA/MIC pass.
     rx_req<=1;rx_write<=1;rx_addr<=0;rx_wdata<=32'h00000208;state<=RX_HEAD;
    end
    RX_HEAD:begin rx_req<=1;rx_write<=0;rx_addr<=rx_config_index==0?8'hd4:8'hd8;state<=RX_HEAD_WAIT;end
    RX_HEAD_WAIT:if(rx_rvalid) begin
     if(rx_config_index==0) begin rx_lengths<=rx_rdata;rx_config_index<=1;state<=RX_HEAD;end
     else begin
      rx_details<=rx_rdata;wire_len<=rx_lengths[26:16];word_count<=rx_rdata[9:0];word_index<=0;
      crc_ok<=rx_header[4]&&!rx_header[5];mic_applicable<=security!=0;mic_pass<=0;ram_written<=0;
      if(rx_lengths[26:16]>capacity || rx_lengths[26:16]>cs_words[28] || rx_lengths[15:0]!={2'd0,rx_lengths[26:16],3'd0} ||
         rx_rdata[9:0]!=(({1'b0,rx_lengths[26:16]}+3)>>2) || (security!=0&&rx_lengths[26:16]<4)) begin
       status_word<=16'h0004;deliver<=0;state<=RX_ACK;
      end else begin
       payload_len<=rx_lengths[26:16]-(security!=0?11'd4:0);
       status_word<=(!rx_header[4]?16'h0008:0)|(rx_header[5]?16'h0004:0)|(rx_header[8]?16'h0040:0)|
        (rx_header[2:0]!=tx_frame_type?16'h0001:0);
       if(rx_lengths[26:16]==0) state<=RX_ACK;else state<=RX_DATA;
      end
     end
    end
    RX_DATA:begin rx_req<=1;rx_write<=0;rx_addr<=8'hdc;state<=RX_DATA_WAIT;end
    RX_DATA_WAIT:if(rx_rvalid) begin load_word<=rx_rdata;state<=RX_STORE;end
    RX_STORE:begin
     store_we<=1;store_addr<=word_index[8:0];store_data<=load_word;store_be<=15;
     if(word_index+1==word_count) state<=RX_ACK;
     else begin word_index<=word_index+1'b1;state<=RX_DATA;end
    end
    RX_ACK:begin
     rx_req<=1;rx_write<=1;rx_addr<=8'h3c;rx_wdata<=1;
     if(!sync_seen) status_word[0]<=1;
     if(status_word[2]) begin deliver<=0;word_count<=0;state<=RX_WRITE_READ;end
     else if(security!=0 && crc_ok && !nonce_valid)begin
      status_word[4]<=1;mic_pass<=0;deliver<=0;word_index<=0;state<=RX_WRITE_READ;
     end
     else if(security!=0 && crc_ok) begin crypto_start<=1;state<=RX_CRYPTO;end
     else begin deliver<=crc_ok&&sync_seen&&!rx_header[8]&&rx_header[2:0]==tx_frame_type;word_index<=0;state<=RX_WRITE_READ;end
    end
    RX_CRYPTO:if(crypto_done) begin
     mic_pass<=crypto_mic_ok&&!crypto_error;deliver<=crc_ok&&crypto_mic_ok&&!crypto_error&&!status_word[0]&&!rx_header[8];
     if(!crypto_mic_ok||crypto_error) status_word[4]<=1;
     word_index<=0;state<=RX_WRITE_READ;
    end
    RX_WRITE_READ:begin
     if(word_count==0) begin writeback_index<=0;state<=WRITEBACK;end
     else begin buffer_read<=1;buffer_addr<=word_index[8:0];state<=RX_WRITE_Q;end
    end
    RX_WRITE_Q:if(buffer_valid) begin load_word<=buffer_data;state<=RX_WRITE;end
    RX_WRITE:begin
     // RXDATAPTR may be halfword aligned. Split at halfword boundaries;
     // never write beyond capacity or the frame's valid final octet.
     if(data_ptr[0]) begin
      issue_half(1,({1'b0,data_ptr}<<1)+{5'd0,word_index,2'd0},load_word[15:0],RX_WRITE_WAIT);
      if(wire_len-{word_index,2'd0}==1) raw_be<=4'b0100;
     end else begin
      em_req<=1;em_write<=1;em_addr<=({1'b0,data_ptr}<<1)+{5'd0,word_index,2'd0};em_wdata<=load_word;
      remaining=wire_len-{word_index,2'd0};em_be<=keep_for(remaining);state<=RX_WRITE_WAIT;
     end
    end
    RX_WRITE_WAIT:begin
     if(data_ptr[0]) begin
      // The second halfword is written using a dedicated continuation.
      if(wire_len>{word_index,2'd0}+2) begin
       raw_write<=1;raw_addr<=({1'b0,data_ptr}<<1)+{5'd0,word_index,2'd0}+2;raw_data<={16'd0,load_word[31:16]};
       raw_be<=wire_len==({word_index,2'd0}+3)?4'b0001:4'b0011;return_state<=RX_WRITE_READ;
       word_index<=word_index+1'b1;state<=RAW_REQUEST;
       if(word_index+1==word_count) begin return_state<=WRITEBACK;writeback_index<=0;ram_written<=1;end
      end else begin ram_written<=1;writeback_index<=0;state<=WRITEBACK;end
     end else if(em_ack) begin
      em_req<=0;
      if(em_fault) finish_error(`SLE_BUS_FAULT);
      else if(word_index+1==word_count) begin ram_written<=1;writeback_index<=0;state<=WRITEBACK;end
      else begin word_index<=word_index+1'b1;state<=RX_WRITE_READ;end
     end
    end
    WRITEBACK:begin
     if(is_tx) begin
      if(writeback_index==0) issue_half(1,({3'd0,desc_ptr}<<1),16'h8000|{2'd0,next_desc},WRITEBACK_WAIT);
      else state<=PACKET_EVENT;
     end else begin
      case(writeback_index)
       0:issue_half(1,({3'd0,desc_ptr}<<1)+2,status_word,WRITEBACK_WAIT);
       1:issue_half(1,({3'd0,desc_ptr}<<1)+8,sync_slot[15:0],WRITEBACK_WAIT);
       2:issue_half(1,({3'd0,desc_ptr}<<1)+10,{2'd0,sync_slot[29:16]},WRITEBACK_WAIT);
       3:issue_half(1,({3'd0,desc_ptr}<<1)+12,{desc_words[6][15:10],sync_fine},WRITEBACK_WAIT);
       4:begin
        em_req<=1;em_write<=1;em_addr<=({1'b0,meta_ptr}<<1)+4;em_wdata<={5'd0,capacity,5'd0,wire_len};em_be<=15;return_state<=WRITEBACK_WAIT;state<=RAW_WAIT;
       end
       5:begin
        em_req<=1;em_write<=1;em_addr<=({1'b0,meta_ptr}<<1)+8;em_wdata<=rx_header;em_be<=15;return_state<=WRITEBACK_WAIT;state<=RAW_WAIT;
       end
       6:begin
        em_req<=1;em_write<=1;em_addr<=({1'b0,meta_ptr}<<1)+12;
        em_wdata<={27'd0,deliver,mic_pass,mic_applicable,crc_ok,ram_written};em_be<=15;return_state<=WRITEBACK_WAIT;state<=RAW_WAIT;
       end
       7:issue_half(1,({3'd0,desc_ptr}<<1),16'h8000|{2'd0,next_desc},WRITEBACK_WAIT);
       default:state<=PACKET_EVENT;
      endcase
     end
    end
    WRITEBACK_WAIT:begin writeback_index<=writeback_index+1'b1;state<=WRITEBACK;end
    PACKET_EVENT:begin
     if((is_tx&&tx_irq_en)||(!is_tx&&rx_irq_en)) begin
      if(!event_valid) begin
       event_valid<=1;
       event_data<={2'd0,(is_tx?14'd0:desc_ptr),now_fine,now_slot,8'd0,(is_tx?`SLE_EV_TX:`SLE_EV_RX),active_index};
      end
      if(event_valid&&event_ready) begin event_valid<=0;state<=NEXT_PACKET;end
     end else state<=NEXT_PACKET;
    end
    NEXT_PACKET:begin
     // Independent monotonic counters; failed/duplicate RX does not consume
     // the expected RX count. A used maximum value cannot wrap and reuse a nonce.
     if(security!=0)begin
      if(is_tx)begin
       if(&tx_security_counter)tx_counter_exhausted<=1;
       else tx_security_counter<=tx_security_counter+1'b1;
      end else if(deliver)begin
       if(&rx_security_counter)rx_counter_exhausted<=1;
       else rx_security_counter<=rx_security_counter+1'b1;
      end
     end
     if(is_tx) begin tx_cursor<=next_desc;tx_meta_cursor<=next_meta;end
     else begin rx_cursor<=next_desc;rx_meta_cursor<=next_meta;end
     if(coex_revoked===1'b1)begin final_status<=`SLE_CANCELLED;final_reason<=`SLE_CONFLICT;state<=STOP;end
     else if(cancel_latched || window_expired) begin final_status<=cancel_latched?`SLE_CANCELLED:`SLE_DONE;final_reason<=cancel_latched?`SLE_SW_CANCEL:`SLE_WINDOW_END;state<=STOP;end
     else if(!mode[1] && next_desc!=0) begin
      if(next_desc==desc_ptr || next_meta==0 || next_meta==meta_ptr) finish_error(`SLE_BAD_DESC);
      else begin desc_ptr<=next_desc;meta_ptr<=next_meta;desc_index<=0;state<=DESC_REQ;end
     end else if(mode[1] && !phase) begin
      phase<=1;desc_ptr<=mode==2?rx_cursor:tx_cursor;meta_ptr<=mode==2?rx_meta_cursor:tx_meta_cursor;
      if((mode==2?rx_cursor:tx_cursor)==0) begin final_reason<=`SLE_NO_BUFFER;state<=STOP;end
      else begin gap_finish<=0;gap_elapsed<=0;state<=GAP;end
     end else if(mode[1] && phase && cont && (mode==2?tx_cursor:rx_cursor)!=0) begin
      phase<=0;desc_ptr<=mode==2?tx_cursor:rx_cursor;meta_ptr<=mode==2?tx_meta_cursor:rx_meta_cursor;
      gap_finish<=0;gap_elapsed<=0;state<=GAP;
     end else if(elapsed<min_ticks) begin gap_finish<=1;gap_elapsed<=0;state<=GAP;end
     else begin if(!is_tx)final_reason<=`SLE_NO_BUFFER;state<=STOP;end
    end
    GAP:begin
     if(coex_revoked===1'b1)begin final_status<=`SLE_CANCELLED;final_reason<=`SLE_CONFLICT;state<=STOP;end
     else if(cancel_latched || window_expired) begin final_status<=cancel_latched?`SLE_CANCELLED:`SLE_DONE;final_reason<=cancel_latched?`SLE_SW_CANCEL:`SLE_WINDOW_END;state<=STOP;end
     else if(gap_finish && elapsed>=min_ticks) state<=STOP;
     else if(!gap_finish && gap_elapsed>=cfg[7*32+:16]) begin desc_index<=0;packet_elapsed<=0;state<=DESC_REQ;end
    end
    STOP:begin
     tx_cfg_valid<=0;tx_valid<=0;rx_stop<=1;tx_stop<=1;
     // Genuine quiescence is required. Missing PHY signals keep BUSY set.
     if((!tx_touched||tx_quiescent) && (!rx_touched||rx_drain_done) && !em_req && !crypto_busy) begin
      running<=0;rx_stop<=0;tx_stop<=0;
      if(requeue_pending&&!cancel_latched) begin abandoned<=1;state<=IDLE;end
      else state<=FINISH;
     end
    end
    FINISH:begin running<=0;done<=1;state<=IDLE;end
    RAW_REQUEST:begin
     em_req<=1;em_write<=raw_write;em_addr<=raw_addr;em_wdata<=raw_data;em_be<=raw_be;state<=RAW_WAIT;
    end
    RAW_WAIT:if(em_ack) begin
     em_req<=0;
     if(em_fault) finish_error(`SLE_BUS_FAULT);
     else begin half_value=byte_address[1]?em_rdata[31:16]:em_rdata[15:0];state<=return_state;end
    end
    default:state<=IDLE;
   endcase
   if(tx_error && state!=IDLE && state!=STOP && state!=FINISH) finish_error(`SLE_BAD_DESC);
   if(security!=0&&is_tx&&stream_sink_ready)begin
    tx_valid<=stream_valid;
    if(stream_valid)begin tx_data<=stream_data;tx_keep<=stream_keep;tx_last<=stream_last;end
   end
   if(stream_valid&&stream_sink_ready)begin store_we<=1;store_addr<=stream_output_index;store_data<=stream_data;store_be<=stream_keep;stream_output_index<=stream_output_index+1'b1;end
   // A pre-start cancellation/reselection drains the in-flight memory access
   // before discarding the prepared context. It never changes ET ownership.
   if(!running && state!=IDLE && state!=STOP && state!=FINISH && !em_req && !crypto_busy &&
      !(state==TX_WAIT_START&&tx_air_started) && !(state==RX_RUN&&rx_window_started) && (requeue||cancel_latched)) begin
    em_req<=0;rx_req<=0;tx_cfg_valid<=0;tx_valid<=0;
    if(tx_cfg_valid&&tx_cfg_ready)tx_touched<=1;
    if(requeue&&!cancel_latched) requeue_pending<=1;
    else begin final_status<=`SLE_CANCELLED;final_reason<=`SLE_SW_CANCEL;end
    state<=STOP;
   end
  end
 end
endmodule
`default_nettype wire
