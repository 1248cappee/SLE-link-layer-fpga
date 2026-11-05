`default_nettype none
module rw_ble_event_cntl(
 input wire clk,rst_n,accept,complete,abandon,cancel,
 input wire started,tick,packet_fact,phase_is_tx,engine_running,coex_enable,coex_grant,
 input wire [4:0] job_priority,
 input wire [1167:0] cs_image,
 input wire [78:0] scan_map,
 input wire [3:0] role,
 input wire [2:0] mode,
 output wire [2:0] checked_mode,
 output wire cancel_out,active,cs_layout_valid,radio_grant,scan_valid,
 output wire [6:0] scan_channel,
 output wire [31:0] event_elapsed,
 output wire [4:0] pti
);
 wire [10:0] selected,allowed;
 wire [2:0] mode_error;
 wire [13:0] cs_tx,cs_rx;
 wire [15:0] min_time,max_time,rx_window,rx_time,rx_bytes;
 wire minimum_met,maximum_met,timer_active,scan_done;
 rw_ble_event_cntl_advert u_rw_ble_event_cntl_advert(.role(role),.mode(mode),.selected(selected[0]),.mode_allowed(allowed[0]));
 rw_ble_event_cntl_scaninit u_rw_ble_event_cntl_scaninit(.role(role),.mode(mode),.selected(selected[1]),.mode_allowed(allowed[1]));
 rw_ble_event_cntl_master u_rw_ble_event_cntl_master(.role(role),.mode(mode),.selected(selected[2]),.mode_allowed(allowed[2]));
 rw_ble_event_cntl_slave u_rw_ble_event_cntl_slave(.role(role),.mode(mode),.selected(selected[3]),.mode_allowed(allowed[3]));
 rw_ble_event_cntl_iso0master u_rw_ble_event_cntl_iso0master(.role(role),.mode(mode),.selected(selected[4]),.mode_allowed(allowed[4]));
 rw_ble_event_cntl_iso0slave u_rw_ble_event_cntl_iso0slave(.role(role),.mode(mode),.selected(selected[5]),.mode_allowed(allowed[5]));
 rw_ble_event_cntl_cismaster u_rw_ble_event_cntl_cismaster(.role(role),.mode(mode),.selected(selected[6]),.mode_allowed(allowed[6]));
 rw_ble_event_cntl_cisslave u_rw_ble_event_cntl_cisslave(.role(role),.mode(mode),.selected(selected[7]),.mode_allowed(allowed[7]));
 rw_ble_event_cntl_bismaster u_rw_ble_event_cntl_bismaster(.role(role),.mode(mode),.selected(selected[8]),.mode_allowed(allowed[8]));
 rw_ble_event_cntl_bisslave u_rw_ble_event_cntl_bisslave(.role(role),.mode(mode),.selected(selected[9]),.mode_allowed(allowed[9]));
 rw_ble_event_cntl_test u_rw_ble_event_cntl_test(.role(role),.mode(mode),.selected(selected[10]),.mode_allowed(allowed[10]));
 rw_ble_event_cntl_em_manager u_rw_ble_event_cntl_em_manager(.cs(cs_image),.et_mode(mode),.valid(cs_layout_valid),
  .tx_ptr(cs_tx),.rx_ptr(cs_rx),.min_time(min_time),.max_time(max_time),.rx_window(rx_window),.rx_max_time(rx_time),.rx_max_bytes(rx_bytes));
 rw_ble_event_cntl_timers u_rw_ble_event_cntl_timers(.clk(clk),.rst_n(rst_n),.start(started),.tick(tick),.stop(complete||abandon),
  .min_time(min_time),.max_time(max_time),.elapsed(event_elapsed),.minimum_met(minimum_met),.maximum_met(maximum_met),.active(timer_active));
 rw_ble_event_cntl_scanch u_rw_ble_event_cntl_scanch(.clk(clk),.rst_n(rst_n),.start(accept),.advance(packet_fact),
  .channels(scan_map),.valid(scan_valid),.done(scan_done),.channel(scan_channel));
 rw_ble_event_cntl_pti u_rw_ble_event_cntl_pti(.priority(job_priority),.tx(engine_running&&phase_is_tx),.rx(engine_running&&!phase_is_tx),
  .coex_enable(coex_enable),.grant(coex_grant),.pti(pti),.allowed(radio_grant));
 rw_ble_event_cntl_main u_rw_ble_event_cntl_main(.clk(clk),.rst_n(rst_n),.accept(accept),.complete(complete),.abandon(abandon),.cancel(cancel),
  .mode_allowed(|allowed),.active(active),.cancel_out(cancel_out),.mode_error(mode_error));
 assign checked_mode=(|allowed)?mode:mode_error;
endmodule
`default_nettype wire
