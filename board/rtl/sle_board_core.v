
`default_nettype none
module sle_board_core(
 input wire clk,rst_n,input wire host_req,host_write,input wire [18:0] host_addr,
 input wire [31:0] host_wdata,input wire [3:0] host_be,
 output wire host_wait,output reg [31:0] host_rdata,output wire host_error,
 output wire [255:0] trace
);
 wire  hsel;
 wire  hready_in;
 wire [17:0] haddr;
 wire [1:0] htrans;
 wire  hwrite;
 wire [2:0] hsize;
 wire [31:0] hwdata;
 wire  hready;
 wire [1:0] hresp;
 wire [31:0] hrdata;
 wire  p_rd;
 wire  p_wr;
 wire [17:0] p_ad;
 wire [31:0] p_wdata;
 wire [3:0] p_ben;
 wire  p_wait;
 wire [31:0] p_rdata;
 wire  p_error;
 wire  tx_cfg_valid;
 wire  tx_cfg_ready;
 wire [2:0] tx_frame_type;
 wire [4:0] tx_ctrl_format;
 wire [3:0] tx_mcs;
 wire [6:0] tx_channel;
 wire [15:0] tx_payload_bytes;
 wire [1:0] tx_crc_mode;
 wire [31:0] tx_crc_seed;
 wire [23:0] tx_cb_seed;
 wire [23:0] tx_llid;
 wire [63:0] tx_ctrl_bits;
 wire [6:0] tx_ctrl_len;
 wire  tx_whitening;
 wire  tx_feedback_cbg;
 wire  tx_broadcast;
 wire [1:0] tx_pilot;
 wire [1:0] tx_bandwidth;
 wire [2:0] tx_mseq_id;
 wire [31:0] tx_data;
 wire [3:0] tx_keep;
 wire  tx_valid;
 wire  tx_last;
 wire  tx_ready;
 wire  tx_error;
 wire  tx_launch;
 wire  tx_stop;
 wire  tx_prepared;
 wire  tx_air_started;
 wire  tx_air_done;
 wire  tx_quiescent;
 wire [29:0] tx_start_slot;
 wire [9:0] tx_start_fine;
 wire  rx_req;
 wire  rx_write;
 wire [7:0] rx_addr;
 wire [31:0] rx_wdata;
 wire  rx_rvalid;
 wire  rx_irq;
 wire [31:0] rx_rdata;
 wire  rx_stop;
 wire  rx_window_started;
 wire  rx_drain_done;
 wire  rx_sync_valid;
 wire [29:0] rx_sync_slot;
 wire [9:0] rx_sync_fine;
 wire [31:0] phy_caps;
 wire  irq;
 wire [2:0] timer_irq;
 wire  wlan_busy;
 wire [4:0] wlan_priority;
 wire  coex_request;
 wire [4:0] coex_pti;
 wire  filter_start;
 wire  filter_abort;
 wire [47:0] filter_wanted;
 wire [47:0] filter_mask;
 wire  filter_invert;
 wire  filter_entry_valid;
 wire  filter_entry_last;
 wire [47:0] filter_entry_address;
 wire [15:0] filter_entry_tag;
 wire  filter_entry_ready;
 wire  filter_busy;
 wire  filter_result_valid;
 wire  filter_matched;
 wire [15:0] filter_result_tag;
 wire  filter_result_ready;
 wire  resolve_start;
 wire  resolve_abort;
 wire  resolve_algorithm;
 wire [15:0] resolve_wanted_irk_id;
 wire [15:0] resolve_wanted_hash;
 wire [127:0] resolve_random_message;
 wire [4:0] resolve_random_bytes;
 wire  resolve_entry_valid;
 wire  resolve_entry_last;
 wire [15:0] resolve_entry_irk_id;
 wire [15:0] resolve_entry_tag;
 wire [127:0] resolve_entry_key;
 wire  resolve_entry_ready;
 wire  resolve_busy;
 wire  resolve_result_valid;
 wire  resolve_matched;
 wire  resolve_error;
 wire [15:0] resolve_result_tag;
 wire  resolve_result_ready;
 wire [29:0] debug_slot;
 wire [9:0] debug_fine;
 wire  debug_busy;
 wire [4:0] debug_errors;
 wire [7:0] debug_fifo_count;
 wire [71:0] debug_event;
 reg enabled;reg [31:0] case_id;reg [3:0] ll_reset;
 reg seq_start,seq_abort;wire seq_busy,seq_done,seq_failed;wire [9:0] seq_pc;wire [7:0] seq_reason;
 wire [31:0] seq_actual,seq_expected;wire seq_req,seq_write;wire [17:0] seq_addr;
 wire [31:0] seq_data;wire [3:0] seq_be;
 reg [10:0] rx_length;reg [1:0] rx_flags;reg [15:0] read_latency,sync_delay,mail_delay;
 reg [23:0] air_cycles;reg [7:0] stall_mask;
 wire [15:0] tx_bytes;wire [31:0] model_errors,mail_acks,tx_frames,rx_frames;
 wire ll_rst_n=rst_n&&(ll_reset==0);
 wire debug_access=host_req&&host_addr[18:16]==4;
 wire code_access=debug_access&&host_addr[15:14]==1;
 wire buffer_access=debug_access&&host_addr[15:13]==4;
 wire ctrl_access=debug_access&&host_addr[15:8]==0;
 wire protected_access=code_access||buffer_access;
 wire protected_error=protected_access&&(seq_busy||debug_busy);
 wire control_error=ctrl_access&&host_write&&host_addr[7:0]==8'h10&&(seq_busy||debug_busy||!tx_quiescent||!rx_drain_done);
 wire config_error=ctrl_access&&host_write&&(host_addr[7:0]>=8'h40&&host_addr[7:0]<=8'h58)&&(seq_busy||debug_busy);
 wire buffer_req=buffer_access&&!protected_error;
 wire buffer_wait;wire [31:0] buffer_data;
 wire ll_req=seq_busy?seq_req:(host_req&&!host_addr[18]);
 wire ll_write=seq_busy?seq_write:host_write;
 wire [17:0] ll_addr=seq_busy?seq_addr:host_addr[17:0];
 wire [31:0] ll_data=seq_busy?seq_data:host_wdata;
 wire [3:0] ll_be=seq_busy?seq_be:host_be;
 wire ll_wait,ll_error;wire [31:0] ll_rdata;
 assign host_wait=debug_access?(buffer_req?buffer_wait:1'b0):(seq_busy?1'b0:ll_wait);
 assign host_error=debug_access?(!ctrl_access&&!code_access&&!buffer_access)||protected_error||control_error||config_error:
                         seq_busy||ll_error;
 wire code_load=code_access&&host_write&&!protected_error;
 sle_board_sequence sequence_controller(.clk(clk),.rst_n(rst_n),.start(seq_start),.abort(seq_abort),
 .load(code_load),.load_addr(host_addr[13:2]),.load_data(host_wdata),.load_be(host_be),
 .now_slot(debug_slot),.now_fine(debug_fine),.busy(seq_busy),.done(seq_done),.failed(seq_failed),.pc(seq_pc),.reason(seq_reason),
 .actual(seq_actual),.expected(seq_expected),.req(seq_req),.wr(seq_write),.addr(seq_addr),.data(seq_data),.be(seq_be),
 .wait_i(ll_wait),.rdata(ll_rdata),.error(ll_error));
 always @* begin
  host_rdata=ll_rdata;
  if(debug_access)begin
   host_rdata=0;
   if(buffer_access)host_rdata=buffer_data;
   else if(ctrl_access)case(host_addr[7:0])
    8'h00:host_rdata=32'h534c4254; // SLBT, digital tester build
    8'h04:host_rdata=32'h00010000;
    8'h08:host_rdata={24'd0,rx_drain_done,tx_quiescent,2'd0,debug_busy,seq_failed,seq_done,seq_busy};
    8'h0c:host_rdata=case_id;
    8'h10:host_rdata={31'd0,enabled};
    8'h18:host_rdata={14'd0,seq_reason,seq_pc};
    8'h1c:host_rdata=seq_actual;
    8'h20:host_rdata=seq_expected;
    8'h24:host_rdata={2'd0,debug_slot};
    8'h28:host_rdata={22'd0,debug_fine};
    8'h2c:host_rdata={27'd0,debug_errors};
    8'h30:host_rdata={24'd0,debug_fifo_count};
    8'h40:host_rdata={21'd0,rx_length};
    8'h44:host_rdata={30'd0,rx_flags};
    8'h48:host_rdata={16'd0,read_latency};
    8'h4c:host_rdata={8'd0,air_cycles};
    8'h50:host_rdata={16'd0,sync_delay};
    8'h54:host_rdata={16'd0,mail_delay};
    8'h58:host_rdata={24'd0,stall_mask};
    8'h5c:host_rdata={16'd0,tx_bytes};
    8'h60:host_rdata=model_errors;
    8'h64:host_rdata=mail_acks;
    8'h68:host_rdata=tx_frames;
    8'h6c:host_rdata=rx_frames;
    default:host_rdata=0;
   endcase
  end
 end
 function [31:0] merge;
 input [31:0] old_value,new_value;input [3:0] byte_enable;
 integer k;begin merge=old_value;for(k=0;k<4;k=k+1)if(byte_enable[k])merge[k*8+:8]=new_value[k*8+:8];end
 endfunction
 reg [31:0] merged;
 always @(posedge clk)begin
  if(!rst_n)begin
   enabled<=0;case_id<=0;ll_reset<=8;seq_start<=0;seq_abort<=0;
   rx_length<=17;rx_flags<=1;read_latency<=3;sync_delay<=20;mail_delay<=100;air_cycles<=400;stall_mask<=7;
  end else begin
   seq_start<=0;if(!seq_busy)seq_abort<=0;
   if(ll_reset!=0)ll_reset<=ll_reset-1'b1;
   if(ctrl_access&&host_write&&!host_error)case(host_addr[7:0])
    8'h0c:case_id<=merge(case_id,host_wdata,host_be);
    8'h10:if(host_be[0])enabled<=host_wdata[0];
    8'h14:if(host_be[0])begin
     if(host_wdata[0]&&!seq_busy)seq_start<=1;
     if(host_wdata[1])seq_abort<=1;
     if(host_wdata[2]&&!seq_busy)ll_reset<=8;
    end
    8'h40:if(!debug_busy&&!seq_busy)begin merged=merge({21'd0,rx_length},host_wdata,host_be);rx_length<=merged[10:0];end
    8'h44:if(!debug_busy&&!seq_busy&&host_be[0])rx_flags<=host_wdata[1:0];
    8'h48:if(!debug_busy&&!seq_busy)begin merged=merge({16'd0,read_latency},host_wdata,host_be);read_latency<=merged[15:0];end
    8'h4c:if(!debug_busy&&!seq_busy)begin merged=merge({8'd0,air_cycles},host_wdata,host_be);air_cycles<=merged[23:0];end
    8'h50:if(!debug_busy&&!seq_busy)begin merged=merge({16'd0,sync_delay},host_wdata,host_be);sync_delay<=merged[15:0];end
    8'h54:if(!debug_busy&&!seq_busy)begin merged=merge({16'd0,mail_delay},host_wdata,host_be);mail_delay<=merged[15:0];end
    8'h58:if(!debug_busy&&!seq_busy&&host_be[0])stall_mask<=host_wdata[7:0];
    default:begin end
   endcase
  end
 end
 assign trace={case_id,debug_slot,debug_fine,debug_event,debug_errors,debug_fifo_count,
  model_errors,seq_pc,seq_reason,seq_busy,seq_done,seq_failed,debug_busy,irq,
  tx_cfg_valid,tx_cfg_ready,tx_valid,tx_ready,tx_last,tx_launch,tx_prepared,tx_air_started,tx_air_done,tx_stop,
  rx_req,rx_write,rx_rvalid,rx_irq,rx_sync_valid,rx_stop,rx_drain_done,tx_quiescent,tx_error,host_req,ll_req,ll_wait,ll_error};
 rw_ble_top link_layer(
 .clk(clk),
 .rst_n(ll_rst_n),
 .hsel('d0),
 .hready_in(1'b1),
 .haddr('d0),
 .htrans('d0),
 .hwrite('d0),
 .hsize('d0),
 .hwdata('d0),
 .hready(hready),
 .hresp(hresp),
 .hrdata(hrdata),
 .p_rd(ll_req&&!ll_write),
 .p_wr(ll_req&&ll_write),
 .p_ad(ll_addr),
 .p_wdata(ll_data),
 .p_ben(ll_be),
 .p_wait(ll_wait),
 .p_rdata(ll_rdata),
 .p_error(ll_error),
 .tx_cfg_valid(tx_cfg_valid),
 .tx_cfg_ready(tx_cfg_ready),
 .tx_frame_type(tx_frame_type),
 .tx_ctrl_format(tx_ctrl_format),
 .tx_mcs(tx_mcs),
 .tx_channel(tx_channel),
 .tx_payload_bytes(tx_payload_bytes),
 .tx_crc_mode(tx_crc_mode),
 .tx_crc_seed(tx_crc_seed),
 .tx_cb_seed(tx_cb_seed),
 .tx_llid(tx_llid),
 .tx_ctrl_bits(tx_ctrl_bits),
 .tx_ctrl_len(tx_ctrl_len),
 .tx_whitening(tx_whitening),
 .tx_feedback_cbg(tx_feedback_cbg),
 .tx_broadcast(tx_broadcast),
 .tx_pilot(tx_pilot),
 .tx_bandwidth(tx_bandwidth),
 .tx_mseq_id(tx_mseq_id),
 .tx_data(tx_data),
 .tx_keep(tx_keep),
 .tx_valid(tx_valid),
 .tx_last(tx_last),
 .tx_ready(tx_ready),
 .tx_error(tx_error),
 .tx_launch(tx_launch),
 .tx_stop(tx_stop),
 .tx_prepared(tx_prepared),
 .tx_air_started(tx_air_started),
 .tx_air_done(tx_air_done),
 .tx_quiescent(tx_quiescent),
 .tx_start_slot(tx_start_slot),
 .tx_start_fine(tx_start_fine),
 .rx_req(rx_req),
 .rx_write(rx_write),
 .rx_addr(rx_addr),
 .rx_wdata(rx_wdata),
 .rx_rvalid(rx_rvalid),
 .rx_irq(rx_irq),
 .rx_rdata(rx_rdata),
 .rx_stop(rx_stop),
 .rx_window_started(rx_window_started),
 .rx_drain_done(rx_drain_done),
 .rx_sync_valid(rx_sync_valid),
 .rx_sync_slot(rx_sync_slot),
 .rx_sync_fine(rx_sync_fine),
 .phy_caps(enabled?32'h8000000f:32'd0),
 .irq(irq),
 .timer_irq(timer_irq),
 .wlan_busy('d0),
 .wlan_priority('d0),
 .coex_request(coex_request),
 .coex_pti(coex_pti),
 .filter_start('d0),
 .filter_abort('d0),
 .filter_wanted('d0),
 .filter_mask('d0),
 .filter_invert('d0),
 .filter_entry_valid('d0),
 .filter_entry_last('d0),
 .filter_entry_address('d0),
 .filter_entry_tag('d0),
 .filter_entry_ready(filter_entry_ready),
 .filter_busy(filter_busy),
 .filter_result_valid(filter_result_valid),
 .filter_matched(filter_matched),
 .filter_result_tag(filter_result_tag),
 .filter_result_ready('d0),
 .resolve_start('d0),
 .resolve_abort('d0),
 .resolve_algorithm('d0),
 .resolve_wanted_irk_id('d0),
 .resolve_wanted_hash('d0),
 .resolve_random_message('d0),
 .resolve_random_bytes('d0),
 .resolve_entry_valid('d0),
 .resolve_entry_last('d0),
 .resolve_entry_irk_id('d0),
 .resolve_entry_tag('d0),
 .resolve_entry_key('d0),
 .resolve_entry_ready(resolve_entry_ready),
 .resolve_busy(resolve_busy),
 .resolve_result_valid(resolve_result_valid),
 .resolve_matched(resolve_matched),
 .resolve_error(resolve_error),
 .resolve_result_tag(resolve_result_tag),
 .resolve_result_ready('d0),
 .debug_slot(debug_slot),
 .debug_fine(debug_fine),
 .debug_busy(debug_busy),
 .debug_errors(debug_errors),
 .debug_fifo_count(debug_fifo_count),
 .debug_event(debug_event)
 );
 sle_phy_test tester(
 .clk(clk),
 .rst_n(ll_rst_n),
 .enabled(enabled),
 .now_slot(debug_slot),
 .now_fine(debug_fine),
 .rx_length(rx_length),
 .rx_flags(rx_flags),
 .read_latency(read_latency),
 .air_cycles(air_cycles),
 .sync_delay(sync_delay),
 .mail_delay(mail_delay),
 .stall_mask(stall_mask),
 .buf_req(buffer_req),
 .buf_write(host_write),
 .buf_addr(host_addr[12:2]),
 .buf_wdata(host_wdata),
 .buf_be(host_be),
 .buf_wait(buffer_wait),
 .buf_rdata(buffer_data),
 .tx_cfg_valid(tx_cfg_valid),
 .tx_cfg_ready(tx_cfg_ready),
 .tx_payload_bytes(tx_payload_bytes),
 .tx_data(tx_data),
 .tx_keep(tx_keep),
 .tx_valid(tx_valid),
 .tx_last(tx_last),
 .tx_ready(tx_ready),
 .tx_launch(tx_launch),
 .tx_stop(tx_stop),
 .tx_prepared(tx_prepared),
 .tx_air_started(tx_air_started),
 .tx_air_done(tx_air_done),
 .tx_quiescent(tx_quiescent),
 .tx_error(tx_error),
 .tx_start_slot(tx_start_slot),
 .tx_start_fine(tx_start_fine),
 .rx_req(rx_req),
 .rx_write(rx_write),
 .rx_addr(rx_addr),
 .rx_wdata(rx_wdata),
 .rx_rvalid(rx_rvalid),
 .rx_irq(rx_irq),
 .rx_rdata(rx_rdata),
 .rx_stop(rx_stop),
 .rx_window_started(rx_window_started),
 .rx_sync_valid(rx_sync_valid),
 .rx_drain_done(rx_drain_done),
 .rx_sync_slot(rx_sync_slot),
 .rx_sync_fine(rx_sync_fine),
 .tx_bytes(tx_bytes),
 .errors(model_errors),
 .mail_acks(mail_acks),
 .tx_frames(tx_frames),
 .rx_frames(rx_frames)
 );
endmodule
`default_nettype wire
