"""Generate explicit named-port wiring for the PHY-free board shell."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
header=(ROOT/'rw_ble_top/verilog/rtl/rw_ble_top.v').read_text().split(');',1)[0]
ports=re.findall(r'(input|output) wire\s*(\[[^]]+\])?\s*(\w+)\s*[,\n]',header+'\n')
body=r'''
`default_nettype none
module sle_board_core(
 input wire clk,rst_n,input wire host_req,host_write,input wire [18:0] host_addr,
 input wire [31:0] host_wdata,input wire [3:0] host_be,
 output wire host_wait,output reg [31:0] host_rdata,output wire host_error,
 output wire [255:0] trace
);
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
'''
wires=''
for direction,width,name in ports:
    wires+=f' wire {width} {name};\n'
body=body.replace(' reg enabled;',wires+' reg enabled;')
mapping={'clk':'clk','rst_n':'ll_rst_n','p_rd':'ll_req&&!ll_write','p_wr':'ll_req&&ll_write','p_ad':'ll_addr','p_wdata':'ll_data','p_ben':'ll_be','p_wait':'ll_wait','p_rdata':'ll_rdata','p_error':'ll_error','hready_in':"1'b1"}
# Remove redeclarations of the two wrapper inputs.
body=body.replace(' wire  clk;\n','').replace(' wire  rst_n;\n','')
phy_start=False
for direction,width,name in ports:
    if name=='tx_cfg_valid':phy_start=True
    if name=='wlan_busy':phy_start=False
    if name not in mapping:
        mapping[name]=name if direction=='output' or phy_start else "'d0"
mapping['phy_caps']="enabled?32'h8000000f:32'd0"
body+=' rw_ble_top link_layer(\n'+',\n'.join(f' .{n}({mapping[n]})' for _,_,n in ports)+'\n );\n'
phy_header=(ROOT/'board/rtl/sle_phy_test.v').read_text().split(');',1)[0]
names=[]
for match in re.finditer(r'\b(input|output)\s+(?:wire|reg)\s*(?:\[[^]]+\])?\s*(.*?)(?=\b(?:input|output)\s+(?:wire|reg)|$)',phy_header,re.S):
    names.extend(re.findall(r'\b\w+\b',match.group(2)))
pm={n:n for n in names}
pm.update(rst_n='ll_rst_n',now_slot='debug_slot',now_fine='debug_fine',buf_req='buffer_req',buf_write='host_write',buf_addr='host_addr[12:2]',buf_wdata='host_wdata',buf_be='host_be',buf_wait='buffer_wait',buf_rdata='buffer_data',errors='model_errors')
body+=' sle_phy_test tester(\n'+',\n'.join(f' .{n}({pm[n]})' for n in names)+'\n );\nendmodule\n`default_nettype wire\n'
(ROOT/'board/rtl/sle_board_core.v').write_text(body,encoding='ascii')
print('Generated board core with',len(ports),'explicit link-layer ports')
