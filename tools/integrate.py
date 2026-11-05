"""Assemble the RW top/core/controller hierarchy from explicit named nets.

No unspecified ports or implicit nets are permitted. The generated RTL is
Verilog-2001. Native PHY milestones remain external inputs, never constants.
"""
from pathlib import Path
import re,json
ROOT=Path(__file__).resolve().parents[1]
FILES={p.stem:p for p in ROOT.rglob('*.v') if not {'build','external'} & set(p.relative_to(ROOT).parts)}
ALLOCATION={x['module']:ROOT/x['target'] for x in json.loads((ROOT/'docs/module_allocation.json').read_text(encoding='utf-8'))}
def ports(name):
    text=FILES[name].read_text(encoding='ascii').split(');',1)[0]
    text=re.sub(r'//[^\n]*','',text)
    result={}
    for direction,width,names in re.findall(r'\b(input|output)\s+(?:wire|reg|logic)\s*(\[[^]]+\])?\s*([a-zA-Z_0-9, ]+)',text):
        for n in names.split(','):
            if n.strip():result[n.strip()]=(direction,width)
    assert result,name
    return result
NETS={};INSTANCES=[];EXTRA={'top':'','core':'','cntl':''};VARIABLES={'top':{},'core':{},'cntl':{}}
def net(name,width=''):
    if name in NETS:assert NETS[name]==width,(name,NETS[name],width)
    NETS[name]=width
def instance(module,name,group,mapping=None,params=''):
    ps=ports(module);m={p:p for p in ps};m.update(mapping or {})
    assert set(m)==set(ps),(module,set(m)-set(ps))
    for p,n in m.items():
        if re.fullmatch(r'[A-Za-z_]\w*',n):net(n,ps[p][1])
    INSTANCES.append({'module':module,'name':name,'group':group,'ports':ps,'mapping':m,'params':params})
def var(group,name,width=''):
    net(name,width);VARIABLES[group][name]=width
def extra(group,text):EXTRA[group]+=text+'\n'
def const(width=1,value=0):return f"{width}'d{value}"

# Core controller: packet engine, event-role policy, optional sideband engines.
packet_ports=ports('rw_ble_packet_cntl')
pm={'rst_n':'core_rst_n','cancel':'checked_cancel','requeue':'engine_requeue','idle':'engine_idle','running':'engine_running',
    'started':'engine_started','done':'engine_done','abandoned':'engine_abandoned','final_status':'engine_status','final_reason':'engine_reason',
    'event_valid':'packet_event_valid','event_ready':'packet_event_ready','event_data':'packet_event_data','error_set':'packet_error_set',
    'em_req':'packet_em_req','em_write':'packet_em_write','em_addr':'packet_em_addr','em_wdata':'packet_em_wdata','em_be':'packet_em_be',
    'em_ack':'packet_em_ack','em_fault':'packet_em_fault','em_rdata':'em_rdata','job_mode':'checked_mode',
    'tx_data':'bs_data','tx_keep':'bs_keep','tx_valid':'bs_valid','tx_last':'bs_last','tx_ready':'bs_ready',
    'rx_req':'packet_rx_req','rx_write':'packet_rx_write','rx_addr':'packet_rx_addr','rx_wdata':'packet_rx_wdata',
    'rx_rvalid':'packet_rx_rvalid','rx_rdata':'packet_rx_rdata','rx_drain_done':'qualified_drain'}
instance('rw_ble_packet_cntl','u_rw_ble_packet_cntl','cntl',pm,'.EM_BYTES(EM_BYTES)')
instance('rw_ble_event_cntl','u_rw_ble_event_cntl','cntl',{'rst_n':'core_rst_n','accept':'job_accept','complete':'engine_done','abandon':'engine_abandoned',
    'cancel':'engine_cancel','role':'selected_role','mode':'job_mode','cancel_out':'checked_cancel','active':'role_active',
    'started':'engine_started','tick':'tick_fine','packet_fact':'packet_fact','coex_grant':'coex_granted','pti':'coex_pti'})
net('job_accept');net('selected_role','[3:0]')
net('packet_fact');net('coex_enable');net('scan_map','[78:0]')
extra('cntl',"assign job_accept=job_valid&&job_ready;\nassign selected_role=context_data[23:20];\nassign packet_fact=packet_event_valid&&packet_event_ready;\nassign coex_enable=context_data[27];\nassign scan_map={context_data[26*32+12+:3],context_data[26*32+:12],context_data[25*32+:32],context_data[24*32+:32]};")
# The search engines are callable through explicit streaming auxiliary ports.
# They do not silently inspect a frame with an undefined SLE address layout.
for module,prefix in [('rw_ble_list_search_engine','filter'),('rw_ble_ral_search_engine','resolve')]:
    mapping={p:(p if p=='clk' else 'core_rst_n' if p=='rst_n' else prefix+'_'+p) for p in ports(module)}
    instance(module,'u_'+module,'cntl',mapping)

# Core-level memory, register bank, native transport boundary and helpers.
instance('rw_ble_em_cntl','u_rw_ble_em_cntl','core',{'rst_n':'core_rst_n','req':'em_requests','write':'em_writes','addr':'em_addresses',
 'wdata':'em_write_data','be':'em_byte_enables','ack':'em_acks','fault':'em_faults','rdata':'em_rdata','busy':'em_busy'},'.EM_BYTES(EM_BYTES)')
net('em_requests','[2:0]');net('em_writes','[2:0]');net('em_addresses','[50:0]');net('em_write_data','[95:0]');net('em_byte_enables','[11:0]')
net('host_em_req');net('host_em_write');net('host_em_addr','[16:0]');net('host_em_wdata','[31:0]');net('host_em_be','[3:0]');net('host_em_ack');net('host_em_fault')
extra('core','''assign em_requests={packet_em_req,sch_em_req,host_em_req};
assign em_writes={packet_em_write,sch_em_write,host_em_write};
assign em_addresses={packet_em_addr,sch_em_addr,host_em_addr};
assign em_write_data={packet_em_wdata,sch_em_wdata,host_em_wdata};
assign em_byte_enables={packet_em_be,sch_em_be,host_em_be};
assign {packet_em_ack,sch_em_ack,host_em_ack}=em_acks;
assign {packet_em_fault,sch_em_fault,host_em_fault}=em_faults;''')
instance('rw_ble_reg','u_rw_ble_reg','core',{'rst_n':'core_rst_n','req':'reg_req','write':'host_write','addr':'reg_addr','wdata':'host_wdata','be':'host_be',
 'ack':'reg_ack','error':'reg_error','rdata':'reg_rdata','busy':'controller_busy','scheduler_idle':'scheduler_idle',
 'live_slot':'now_slot','live_fine':'now_fine','context_index':'context_index','bad_cmd':'reg_bad_cmd','cancel':'cancel_command',
 'cancel_index':'cancel_index','snap':'snap_command','load_time':'load_command','soft_reset':'soft_reset_command'},'.EM_BYTES(EM_BYTES),.FIFO_DEPTH(FIFO_DEPTH)')
net('context_index','[3:0]')
extra('core','assign context_index=job_valid?job_index:active_index;')
instance('rw_ble_bit_stream','u_rw_ble_bit_stream','core',{'rst_n':'transport_rst_n','s_data':'bs_data','s_keep':'bs_keep','s_valid':'bs_valid','s_last':'bs_last','s_ready':'bs_ready',
 'm_data':'tx_data','m_keep':'tx_keep','m_valid':'tx_valid','m_last':'tx_last','m_ready':'tx_ready'})
instance('rw_ble_misc_logic','u_rw_ble_misc_logic','core',{'frame_type':'tx_frame_type','control_bits':'tx_ctrl_len','payload_bytes':'wire_payload_length','crc_mode':'tx_crc_mode',
 'ctrl_format':'tx_ctrl_format','mcs':'tx_mcs','valid_control':'control_valid','air_data_bytes':'air_data_bytes'})
net('wire_payload_length','[10:0]');extra('core','assign wire_payload_length=tx_payload_bytes[10:0];')
net('transport_rst_n');extra('core','assign transport_rst_n=core_rst_n&&!tx_stop;')
instance('rw_ble_freq_select','u_rw_ble_freq_select','core',{'rst_n':'core_rst_n','start':'job_accept','slot':'job_slot','sync_or_llid':'hop_input','channel_map':'hop_map',
 'done':'hop_done','error':'hop_error','channel':'hop_channel','random_value':'hop_random'})
net('hop_input','[31:0]');net('hop_map','[75:0]')
extra('core','assign hop_input=(context_data[2:0]>=3)?{8\'d0,context_data[1*32+:24]}:context_data[20*32+:32];\nassign hop_map={context_data[26*32+:12],context_data[25*32+:32],context_data[24*32+:32]};')

# Top-level shared functions, exactly the architectural location of rw_cm_*.
instance('rw_cm_timing_gen','u_rw_cm_timing_gen','top',{'rst_n':'core_rst_n','load_time':'load_command','snap':'snap_command','slot':'now_slot','fine':'now_fine','fired':'timer_fire'},'.CLK_HZ(CLK_HZ)')
instance('rw_cm_int_cntl','u_rw_cm_int_cntl','top',{'rst_n':'core_rst_n','mask':'int_mask','ack':'int_ack','timer_fire':'timer_fire','clock_fire':'tick_slot',
 'fifo_nonempty':'fifo_nonempty','error_level':'error_level','status':'int_status'},'')
instance('sle_event_fifo','u_event_fifo','top',{'rst_n':'core_rst_n','push':'fifo_push','pop':'fifo_pop','in_event':'fifo_input','head':'head_event','count':'fifo_count',
 'full':'fifo_full','empty':'fifo_empty','overflow':'fifo_overflow'},'.DEPTH(FIFO_DEPTH)')
instance('rw_cm_activity_scheduler','u_rw_cm_activity_scheduler','top',{'rst_n':'core_rst_n','enable':'scheduler_enable','freeze':'freeze','now_slot':'now_slot','now_fine':'now_fine',
 'commit':'commit','commit_index':'commit_index','commit_slot':'now_slot','commit_fine':'now_fine','cancel':'cancel_command','cancel_index':'cancel_index',
 'terminal_pop':'terminal_pop','pop_index':'pop_index','clear_start':'clear_start','clear_done':'clear_done','idle':'scheduler_idle',
 'em_req':'sch_em_req','em_write':'sch_em_write','em_addr':'sch_em_addr','em_wdata':'sch_em_wdata','em_be':'sch_em_be','em_ack':'sch_em_ack','em_fault':'sch_em_fault','em_rdata':'em_rdata',
 'event_valid':'sch_event_valid','event_ready':'sch_event_ready','event_data':'sch_event_data','error_set':'sch_error_set'},'.EM_BYTES(EM_BYTES)')
instance('rw_cm_radio_cntl','u_rw_cm_radio_cntl','top',{'rst_n':'core_rst_n','s_req':'packet_rx_req','s_write':'packet_rx_write','s_addr':'packet_rx_addr','s_wdata':'packet_rx_wdata',
 's_rvalid':'packet_rx_rvalid','s_rdata':'packet_rx_rdata','mac_req':'rx_req','mac_write':'rx_write','mac_addr':'rx_addr','mac_wdata':'rx_wdata',
 'mac_rvalid':'rx_rvalid','mac_rdata':'rx_rdata','stop':'rx_stop','drain_done':'rx_drain_done','stop_done':'qualified_drain','fault':'radio_fault'})
instance('rw_cm_wlan_coex_cntl','u_rw_cm_wlan_coex_cntl','top',{'enable':'coex_enable','local_tx':'coex_tx','local_rx':'coex_rx','peer_busy':'wlan_busy',
 'local_priority':'job_priority','peer_priority':'wlan_priority','request':'coex_requested','grant':'coex_local_grant'})
instance('rw_cm_coex_if','u_rw_cm_coex_if','top',{'rst_n':'core_rst_n','enable':'coex_enable','request':'coex_requested','grant_async':'coex_local_grant',
 'granted':'coex_granted','request_out':'coex_request'})
net('coex_tx');net('coex_rx');extra('top','assign coex_tx=engine_running&&phase_is_tx;\nassign coex_rx=engine_running&&!phase_is_tx;')
instance('rw_cm_ahb_if','u_rw_cm_ahb_if','top',{'req':'ahb_req','write':'ahb_write','addr':'ahb_addr','wdata':'ahb_wdata','be':'ahb_be',
 'ack':'ahb_ack','error':'host_error','rdata':'host_rdata'})
instance('rw_cm_xbar_if','u_rw_cm_xbar_if','top',{'req':'xbar_req','write':'xbar_write','addr':'xbar_addr','wdata':'xbar_wdata','be':'xbar_be',
 'ack':'xbar_ack','error':'host_error','rdata':'host_rdata'})
# These optional co-existence interfaces are disabled in the default P101
# profile; their synchronizers/arbitration remain independent usable modules.
instance('rw_cm_diag_cntl','u_rw_cm_diag_cntl','top',{'rst_n':'core_rst_n','clear':"1'b0",'access':'host_em_ack','write':'host_em_write','address':'host_em_addr',
 'minimum':'diag_min','maximum':'diag_max','read_count':'diag_reads','write_count':'diag_writes'})

for n,w in [('host_req',''),('host_write',''),('host_addr','[17:0]'),('host_wdata','[31:0]'),('host_be','[3:0]'),('host_ack',''),('host_error',''),
 ('host_rdata','[31:0]'),('reg_req',''),('reg_addr','[11:0]'),('host_decode_error',''),('core_rst_n',''),('controller_busy',''),('scheduler_enable',''),
 ('freeze',''),('commit',''),('commit_index','[3:0]'),('terminal_pop',''),('pop_index','[3:0]'),('fifo_push',''),('fifo_input','[71:0]'),
 ('fifo_nonempty',''),('error_level',''),('fifo_backlog_fault','')]:net(n,w)
for n,w in [('error_status','[4:0]'),('reset_state','[1:0]'),('reset_count','[3:0]'),('clear_start',''),('fatal_latched','')]:var('top',n,w)
extra('top','''assign core_rst_n=rst_n&&(reset_state!=3);
assign host_req=(HOST_INTERFACE==0)?xbar_req:ahb_req;
assign host_write=(HOST_INTERFACE==0)?xbar_write:ahb_write;
assign host_addr=(HOST_INTERFACE==0)?xbar_addr:ahb_addr;
assign host_wdata=(HOST_INTERFACE==0)?xbar_wdata:ahb_wdata;
assign host_be=(HOST_INTERFACE==0)?xbar_be:ahb_be;
assign xbar_ack=host_ack&&(HOST_INTERFACE==0);
assign ahb_ack=host_ack&&(HOST_INTERFACE!=0);
assign reg_addr=host_addr[11:0];
assign host_decode_error=host_req&&!host_addr[17]&&(host_addr[16:12]!=0||host_addr[1:0]!=0);
assign reg_req=host_req&&!host_addr[17]&&!host_decode_error;
assign host_em_req=host_req&&host_addr[17]&&(reset_state==0);
assign host_em_write=host_write;assign host_em_addr=host_addr[16:0];
assign host_em_wdata=host_wdata;assign host_em_be=host_be;
assign host_ack=host_decode_error||(host_addr[17]?host_em_ack:reg_ack);
assign host_error=host_decode_error||(host_addr[17]?host_em_fault:reg_error);
assign host_rdata=host_addr[17]?em_rdata:reg_rdata;
assign commit=host_em_ack&&host_em_write&&host_em_be[0]&&host_em_be[1]&&
 (host_em_addr>=({3'd0,etptr}<<1))&&(host_em_addr<({3'd0,etptr}<<1)+256)&&
 ((host_em_addr-({3'd0,etptr}<<1))&17'hf)==0&&host_em_wdata[5:3]==3'd1;
assign commit_index=(host_em_addr-({3'd0,etptr}<<1))>>4;
assign scheduler_enable=enable&&schedule_enable&&!fatal_latched;
assign freeze=reset_state!=0||fatal_latched;
assign controller_busy=reset_state!=0||!scheduler_idle||!engine_idle||em_busy;
assign fifo_nonempty=!fifo_empty;assign error_level=|error_status;
assign terminal_pop=fifo_pop&&!fifo_empty&&(head_event[7:4]>=2&&head_event[7:4]<=5);
assign pop_index=head_event[3:0];
assign fifo_push=(reset_state==0)&&!fifo_full&&(sch_event_valid||packet_event_valid);
assign fifo_input=sch_event_valid?sch_event_data:packet_event_data;
assign sch_event_ready=!fifo_full||(reset_state!=0);
assign packet_event_ready=(!fifo_full&&!sch_event_valid)||(reset_state!=0);
assign fifo_backlog_fault=fifo_full&&(sch_event_valid||packet_event_valid);
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin error_status<=0;fatal_latched<=0;reset_state<=0;reset_count<=0;clear_start<=0;end
 else begin
  clear_start<=0;
  if(!core_rst_n) begin error_status<=0;fatal_latched<=0;end
  else begin
   error_status<=(error_status&~error_ack)|sch_error_set|packet_error_set|
    {reg_bad_cmd||host_decode_error,radio_fault,fifo_overflow||fifo_backlog_fault,2'b00};
   if(error_status[3:2]!=0||radio_fault||fifo_backlog_fault) fatal_latched<=1;
  end
  case(reset_state)
   0:if(soft_reset_command) reset_state<=1;
   1:if(engine_idle&&!sch_em_req&&!packet_em_req&&!em_busy) begin clear_start<=1;reset_state<=2;end
   2:if(clear_done) begin reset_state<=3;reset_count<=0;end
   3:if(reset_count==7) reset_state<=0;else reset_count<=reset_count+1'b1;
  endcase
 end
end''')

# Top public ports: host buses, PHY, and explicit streaming search auxiliaries.
EXTERNAL={'clk':('input',''),'rst_n':('input','')}
host=['hsel','hready_in','haddr','htrans','hwrite','hsize','hwdata','hready','hresp','hrdata','p_rd','p_wr','p_ad','p_wdata','p_ben','p_wait','p_rdata','p_error']
phy=list(packet_ports)[list(packet_ports).index('tx_cfg_valid'):]
for name in host+phy+['irq','timer_irq','wlan_busy','wlan_priority','coex_request','coex_pti']:
    candidates=[]
    for ins in INSTANCES:
        for p,n in ins['mapping'].items():
            if n==name:candidates.append(ins['ports'][p])
    # At the top boundary outputs are produced by a submodule, inputs aren't.
    out=[x for x in candidates if x[0]=='output']
    EXTERNAL[name]=('output' if out else 'input',NETS[name])
for ins in INSTANCES:
    if ins['module'] in ('rw_ble_list_search_engine','rw_ble_ral_search_engine'):
        for p,n in ins['mapping'].items():
            if p not in ('clk','rst_n'):EXTERNAL[n]=ins['ports'][p]

def signals(text):return set(re.findall(r'\b[A-Za-z_]\w*\b',text))&NETS.keys()
def used(ins):return set().union(*(signals(n) for n in ins['mapping'].values()))
def wrapper(name,children,group,boundary):
    used_nets=set().union(*(used(x) for x in children))|signals(EXTRA[group])
    output='// Generated by tools/integrate.py. Explicit RW architectural hierarchy.\n`default_nettype none\n'
    output+=f'module {name} #(parameter integer EM_BYTES=131072,FIFO_DEPTH=64,CLK_HZ=20000000,HOST_INTERFACE=0)(\n'
    output+=',\n'.join(f' {d} wire {w} {n}'.replace('wire  ','wire ') for n,(d,w) in boundary.items())+'\n);\n'
    for n in sorted(used_nets-set(boundary)):
        output+=f' {"reg" if n in VARIABLES[group] else "wire"} {NETS[n]} {n};\n'
    output+=EXTRA[group]
    for ins in children:
        param=f' #({ins["params"]})' if ins['params'] else ''
        output+=f' {ins["module"]}{param} {ins["name"]}(\n'
        output+=',\n'.join(f'  .{p}({n})' for p,n in ins['mapping'].items())+'\n );\n'
    output+='endmodule\n`default_nettype wire\n'
    ALLOCATION[name].write_text(output,encoding='ascii')
    return {'module':name,'name':'u_'+name,'group':'core' if group=='cntl' else 'top','ports':boundary,
            'mapping':{n:n for n in boundary},'params':'.EM_BYTES(EM_BYTES),.FIFO_DEPTH(FIFO_DEPTH),.CLK_HZ(CLK_HZ),.HOST_INTERFACE(HOST_INTERFACE)'}

working=INSTANCES[:]
for group,name in [('cntl','rw_ble_core_cntl'),('core','rw_ble_core')]:
    inside=[x for x in working if x['group']==group];outside=[x for x in working if x['group']!=group]
    inside_used=set().union(*(used(x) for x in inside))|signals(EXTRA[group])
    outside_used=set(EXTERNAL)|set().union(*(used(x) for x in outside))
    for other in EXTRA:
        if other!=group:outside_used|=signals(EXTRA[other])
    boundary={}
    for n in sorted(inside_used&outside_used):
        produced=any(ins['ports'][p][0]=='output' and value==n for ins in inside for p,value in ins['mapping'].items())
        # Continuous assignments in this group are also output drivers.
        produced|=bool(re.search(r'assign\s+(?:\{[^}]*\b'+re.escape(n)+r'\b[^}]*\}|'+re.escape(n)+r')\s*=',EXTRA[group]))
        boundary[n]=('output' if produced else 'input',NETS[n])
    working=outside+[wrapper(name,inside,group,boundary)]
wrapper('rw_ble_top',[x for x in working if x['group']=='top'],'top',EXTERNAL)
print('Generated rw_ble_top -> rw_ble_core -> rw_ble_core_cntl with explicit native PHY ports.')
