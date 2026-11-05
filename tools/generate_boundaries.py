"""Generate explicit role policies and elastic external-PHY boundary wrappers.

These modules do not implement PHY algorithms. They preserve the RW file and
instance allocation while transporting the native PHY payload handshake.
"""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
allocation=json.loads((ROOT/'docs/module_allocation.json').read_text(encoding='utf-8'))
paths={x['module']:ROOT/x['target'] for x in allocation}
def put(name, body):
    paths[name].write_text('`default_nettype none\n'+body+'\n`default_nettype wire\n',encoding='ascii')

roles=[('advert',0,1),('scaninit',1,14),('master',2,5),('slave',3,10),
       ('iso0master',4,5),('iso0slave',5,10),('cismaster',6,12),('cisslave',7,12),
       ('bismaster',8,1),('bisslave',9,2),('test',10,15)]
for suffix, role, mask in roles:
    name='rw_ble_event_cntl_'+suffix
    put(name,f'''// Role {role}: mode mask 0x{mask:x}. Policy only; execution is in packet control.
module {name}(
 input wire [3:0] role,
 input wire [2:0] mode,
 output wire selected,mode_allowed
);
 assign selected=role==4'd{role};
 assign mode_allowed=selected && mode<4 && ((4'h{mask:x}>>mode)&1'b1);
endmodule''')
put('rw_ble_event_cntl_main','''module rw_ble_event_cntl_main(
 input wire clk,rst_n,accept,complete,abandon,cancel,
 input wire mode_allowed,
 output reg active,
 output wire cancel_out,
 output wire [2:0] mode_error
);
 assign cancel_out=cancel&&active;
 assign mode_error=mode_allowed?3'd0:3'd7;
 always @(posedge clk or negedge rst_n)
  if(!rst_n) active<=0;
  else if(complete||abandon) active<=0;
  else if(accept) active<=1;
endmodule''')
body='''module rw_ble_event_cntl(
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
'''
for j,(suffix,role,mask) in enumerate(roles):
    body+=f' rw_ble_event_cntl_{suffix} u_rw_ble_event_cntl_{suffix}(.role(role),.mode(mode),.selected(selected[{j}]),.mode_allowed(allowed[{j}]));\n'
body+=''' rw_ble_event_cntl_em_manager u_rw_ble_event_cntl_em_manager(.cs(cs_image),.et_mode(mode),.valid(cs_layout_valid),
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
endmodule'''
put('rw_ble_event_cntl',body)
put('rw_ble_event_cntl_timers','''module rw_ble_event_cntl_timers(
 input wire clk,rst_n,start,tick,stop,
 input wire [15:0] min_time,max_time,
 output reg [31:0] elapsed,
 output wire minimum_met,maximum_met,
 output reg active
);
 reg [15:0] minimum,maximum;
 assign minimum_met=elapsed>=minimum;
 assign maximum_met=active&&elapsed>=maximum;
 always @(posedge clk or negedge rst_n)
  if(!rst_n) begin elapsed<=0;minimum<=0;maximum<=0;active<=0;end
  else if(start) begin elapsed<=0;minimum<=min_time;maximum<=max_time;active<=1;end
  else if(stop) active<=0;
  else if(active&&tick&&elapsed!=32'hffffffff) elapsed<=elapsed+1'b1;
endmodule''')
put('rw_ble_event_cntl_em_manager','''module rw_ble_event_cntl_em_manager #(parameter integer EM_BYTES=131072)(
 input wire [1167:0] cs,
 input wire [2:0] et_mode,
 output wire valid,
 output wire [13:0] tx_ptr,rx_ptr,
 output wire [15:0] min_time,max_time,rx_window,rx_max_time,rx_max_bytes
);
 assign tx_ptr=cs[18*16+:14];assign rx_ptr=cs[17*16+:14];
 assign min_time=cs[23*16+:16];assign max_time=cs[24*16+:16];
 assign rx_window=cs[15*16+:16];assign rx_max_time=cs[29*16+:16];assign rx_max_bytes=cs[28*16+:16];
 assign valid=cs[2:0]==et_mode && et_mode<4 && max_time!=0 && min_time<=max_time &&
  (tx_ptr==0 || ((({3'd0,tx_ptr}<<1)+16<=EM_BYTES)&&(({3'd0,tx_ptr}<<1)+16<=32768))) &&
  (rx_ptr==0 || ((({3'd0,rx_ptr}<<1)+28<=EM_BYTES)&&(({3'd0,rx_ptr}<<1)+28<=32768)));
endmodule''')
put('rw_ble_event_cntl_scanch','''module rw_ble_event_cntl_scanch(
 input wire clk,rst_n,start,advance,
 input wire [78:0] channels,
 output reg valid,done,
 output reg [6:0] channel
);
 reg [78:0] remaining;
 reg [6:0] candidate;
 reg found;
 integer i;
 always @* begin candidate=0;found=0;for(i=0;i<79;i=i+1) if(remaining[i]&&!found) begin candidate=i;found=1;end end
 always @(posedge clk or negedge rst_n)
  if(!rst_n) begin remaining<=0;valid<=0;done<=0;channel<=0;end
  else begin
   done<=0;
   if(start) begin remaining<=channels;valid<=0;end
   else if(!valid) begin
    if(found) begin channel<=candidate;valid<=1;end
   end else if(advance) begin remaining[channel]<=0;valid<=0;if((remaining & ~(79'd1<<channel))==0) done<=1;end
  end
endmodule''')
put('rw_ble_event_cntl_pti','''module rw_ble_event_cntl_pti(
 input wire [4:0] priority,
 input wire tx,rx,coex_enable,grant,
 output wire [4:0] pti,
 output wire allowed
);
 assign pti=(tx||rx)?priority:5'd0;
 assign allowed=!coex_enable||grant;
endmodule''')

ports=''' input wire clk,rst_n,
 input wire [31:0] s_data,
 input wire [3:0] s_keep,
 input wire s_valid,s_last,
 output wire s_ready,
 output wire [31:0] m_data,
 output wire [3:0] m_keep,
 output wire m_valid,m_last,
 input wire m_ready'''
def elastic(name):
    return f'''// External-PHY transport boundary. No CRC/FEC/whitening algorithm here.
module {name}(
{ports}
);
 reg full;
 reg [36:0] payload;
 assign s_ready=!full||m_ready;
 assign m_valid=full;assign m_data=payload[31:0];assign m_keep=payload[35:32];assign m_last=payload[36];
 always @(posedge clk or negedge rst_n)
  if(!rst_n) begin full<=0;payload<=0;end
  else if(s_ready) begin full<=s_valid;if(s_valid) payload<={{s_last,s_keep,s_data}};end
endmodule'''
phy=[x['module'] for x in allocation if x['target'].startswith(('rw_ble_bit_stream/','rw_ble_lr_fec_dec/'))]
assert len(phy)==13
for name in phy:
    if name not in ('rw_ble_bit_stream','rw_ble_lr_fec_dec'):put(name,elastic(name))
def chain(name, children):
    n=len(children)
    body=f'// Native 32-bit payload transport across the preserved RW boundaries.\nmodule {name}(\n{ports}\n);\n'
    body+=f' wire [{n}:0] valid,ready,last;\n wire [{32*(n+1)-1}:0] data;\n wire [{4*(n+1)-1}:0] keep;\n'
    body+=' assign valid[0]=s_valid;assign last[0]=s_last;assign data[31:0]=s_data;assign keep[3:0]=s_keep;assign s_ready=ready[0];\n'
    body+=f' assign m_valid=valid[{n}];assign m_last=last[{n}];assign m_data=data[{n*32}+:32];assign m_keep=keep[{n*4}+:4];assign ready[{n}]=m_ready;\n'
    for i,c in enumerate(children):
        body+=f' {c} u_{c}(.clk(clk),.rst_n(rst_n),.s_data(data[{i*32}+:32]),.s_keep(keep[{i*4}+:4]),.s_valid(valid[{i}]),.s_last(last[{i}]),.s_ready(ready[{i}]),.m_data(data[{(i+1)*32}+:32]),.m_keep(keep[{(i+1)*4}+:4]),.m_valid(valid[{i+1}]),.m_last(last[{i+1}]),.m_ready(ready[{i+1}]));\n'
    return body+'endmodule'
put('rw_ble_lr_fec_dec',chain('rw_ble_lr_fec_dec',['rw_ble_lr_fec_dec_fifo','rw_ble_lr_fec_dec_viterbi','rw_ble_lr_fec_dec_fsm']))
put('rw_ble_bit_stream',chain('rw_ble_bit_stream',[x for x in phy if x not in ('rw_ble_bit_stream','rw_ble_lr_fec_dec_fifo','rw_ble_lr_fec_dec_viterbi','rw_ble_lr_fec_dec_fsm')]))
print('Generated role policy modules and 13 explicit external-PHY transport boundaries.')
