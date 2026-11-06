`default_nettype none
// DIGITAL INTERFACE TESTER ONLY. No modulation, RF or real air timestamps.
module sle_phy_test(
 input wire clk,rst_n,enabled,input wire [29:0] now_slot,input wire [9:0] now_fine,
 input wire [10:0] rx_length,input wire [1:0] rx_flags,input wire [15:0] read_latency,
 input wire [23:0] air_cycles,input wire [15:0] sync_delay,mail_delay,
 input wire [7:0] stall_mask,
 input wire tx_compare_enable,
 output reg [15:0] first_mismatch,
 input wire buf_req,buf_write,input wire [10:0] buf_addr,input wire [31:0] buf_wdata,
 input wire [3:0] buf_be,output wire buf_wait,output reg [31:0] buf_rdata,
 input wire tx_cfg_valid,output wire tx_cfg_ready,input wire [15:0] tx_payload_bytes,
 input wire [31:0] tx_data,input wire [3:0] tx_keep,input wire tx_valid,tx_last,output wire tx_ready,
 input wire tx_launch,tx_stop,output reg tx_prepared,tx_air_started,tx_air_done,
 output wire tx_quiescent,output wire tx_error,output reg [29:0] tx_start_slot,output reg [9:0] tx_start_fine,
 input wire rx_req,rx_write,input wire [7:0] rx_addr,input wire [31:0] rx_wdata,
 output reg rx_rvalid,rx_irq,output reg [31:0] rx_rdata,input wire rx_stop,
 output reg rx_window_started,rx_sync_valid,output wire rx_drain_done,
 output reg [29:0] rx_sync_slot,output reg [9:0] rx_sync_fine,
 output reg [15:0] tx_bytes,output reg [31:0] errors,mail_acks,tx_frames,rx_frames
);
 (* ram_style="block" *) reg [31:0] tx_mem[0:511];
 (* ram_style="block" *) reg [31:0] rx_mem[0:511];
 reg [31:0] rx_word,host_tx_word,host_rx_word;
 reg [31:0] compare_word,compare_data;
 reg [3:0] compare_keep;
 reg [15:0] compare_offset;
 reg compare_pending;
 reg [1:0] host_state;reg [10:0] host_address;reg host_write;
 reg [7:0] phase;reg configured,air_active,rx_active,sent,mailbox,pending;
 reg [15:0] expected_bytes,age,delay_left;reg [23:0] air_left;
 reg [9:0] read_index;reg [7:0] read_address;reg [2:0] frame_type;
 wire [2:0] nbytes={2'b0,tx_keep[0]}+{2'b0,tx_keep[1]}+{2'b0,tx_keep[2]}+{2'b0,tx_keep[3]};
 wire transfer=tx_valid&&tx_ready;
 reg capture_write,host_mem_write;reg [8:0] capture_address,host_mem_address;
 reg [31:0] capture_data,host_mem_data;reg [3:0] host_mem_be;
 integer b;
 assign tx_cfg_ready=enabled&&!configured&&!air_active;
 assign tx_ready=enabled&&configured&&!tx_prepared&&((phase&stall_mask)!=stall_mask||stall_mask==0);
 assign tx_quiescent=!configured&&!air_active;
 assign tx_error=|errors;
 assign rx_drain_done=!rx_active&&!mailbox&&!pending;
 assign buf_wait=buf_req&&host_state!=2;
 // The memory ports have no asynchronous resets. Host must not write buffers
 // while active; the enclosing control block enforces this ownership rule.
 always @(posedge clk)begin
   if(!rst_n)begin capture_write<=0;host_mem_write<=0;end
   else begin capture_write<=transfer&&tx_bytes<2048;host_mem_write<=buf_req&&host_state==0&&buf_write&&buf_addr[10];end
   capture_address<=tx_bytes[10:2];capture_data<=tx_data;
   host_mem_address<=buf_addr[8:0];host_mem_data<=buf_wdata;host_mem_be<=buf_be;
   if(capture_write)tx_mem[capture_address]<=capture_data;
   if(host_mem_write)
    for(b=0;b<4;b=b+1)if(host_mem_be[b])rx_mem[host_mem_address][b*8+:8]<=host_mem_data[b*8+:8];
   host_tx_word<=tx_mem[buf_addr[8:0]];host_rx_word<=rx_mem[buf_addr[8:0]];
   rx_word<=rx_mem[read_index[8:0]];
   compare_word<=rx_mem[tx_bytes[10:2]];
   if(!rst_n)compare_pending<=0;
   else compare_pending<=transfer&&tx_compare_enable;
   compare_data<=tx_data;compare_keep<=tx_keep;compare_offset<=tx_bytes;
 end
 always @(posedge clk)begin
  if(!rst_n)begin
   phase<=0;configured<=0;air_active<=0;tx_prepared<=0;tx_air_started<=0;tx_air_done<=0;tx_bytes<=0;expected_bytes<=0;
   tx_start_slot<=0;tx_start_fine<=0;air_left<=0;errors<=0;mail_acks<=0;tx_frames<=0;rx_frames<=0;
   rx_rvalid<=0;rx_rdata<=0;rx_irq<=0;rx_active<=0;sent<=0;mailbox<=0;pending<=0;age<=0;delay_left<=0;
   rx_window_started<=0;rx_sync_valid<=0;rx_sync_slot<=0;rx_sync_fine<=0;read_index<=0;read_address<=0;frame_type<=1;
   host_state<=0;host_address<=0;host_write<=0;buf_rdata<=0;first_mismatch<=16'hffff;
  end else begin
   phase<=phase+1'b1;tx_air_started<=0;tx_air_done<=0;rx_rvalid<=0;rx_window_started<=0;rx_sync_valid<=0;
   if(compare_pending)for(b=3;b>=0;b=b-1)if(compare_keep[b]&&compare_data[b*8+:8]!=compare_word[b*8+:8])begin
    errors[8]<=1;if(first_mismatch==16'hffff)first_mismatch<=compare_offset+b;
   end
   case(host_state)
    0:if(buf_req)begin host_address<=buf_addr;host_write<=buf_write;host_state<=1;end
    1:begin buf_rdata<=host_address[10]?host_rx_word:host_tx_word;host_state<=2;end
    2:if(!buf_req)host_state<=0;
    default:host_state<=0;
   endcase
   if(tx_cfg_valid&&tx_cfg_ready)begin
    configured<=1;tx_bytes<=0;expected_bytes<=tx_payload_bytes;tx_prepared<=tx_payload_bytes==0;
    if(tx_payload_bytes>2047)errors[0]<=1;
   end
   if(transfer)begin
    if(tx_keep!=1&&tx_keep!=3&&tx_keep!=7&&tx_keep!=15)errors[1]<=1;
    if(!tx_last&&tx_keep!=15)errors[2]<=1;
    tx_bytes<=tx_bytes+nbytes;
    if(tx_bytes+nbytes>expected_bytes)errors[3]<=1;
    if(tx_last)begin tx_prepared<=1;if(tx_bytes+nbytes!=expected_bytes)errors[4]<=1;end
   end
   if(tx_launch)begin
    if(!configured||!tx_prepared||air_active)errors[5]<=1;
    else begin tx_air_started<=1;tx_start_slot<=now_slot;tx_start_fine<=now_fine;air_active<=1;air_left<=air_cycles==0?1:air_cycles;end
   end
   if(air_active)begin
    if(air_left==1)begin air_active<=0;configured<=0;tx_prepared<=0;tx_air_done<=1;tx_frames<=tx_frames+1'b1;end
    else air_left<=air_left-1'b1;
   end
   // A cancellation during a packet drains that packet first.
   if(tx_stop&&!air_active)begin configured<=0;tx_prepared<=0;end
   if(rx_req&&enabled)begin
    if(rx_write)case(rx_addr)
     8'h04:frame_type<=rx_wdata[2:0];
     8'h3c:if(rx_wdata[0])begin mailbox<=0;rx_irq<=0;if(mailbox)mail_acks<=mail_acks+1'b1;end
     8'h00:begin
      rx_active<=rx_wdata[0];
      if(rx_wdata[1])begin rx_window_started<=1;sent<=0;age<=0;read_index<=0;end
      if(rx_wdata[31]&&!mailbox)rx_irq<=0;
     end
     default:begin end
    endcase
    else if(pending)errors[6]<=1;
    else begin pending<=1;read_address<=rx_addr;delay_left<=read_latency<2?2:read_latency;end
   end
   if(pending)begin
    if(delay_left!=0)delay_left<=delay_left-1'b1;
    else begin
     pending<=0;rx_rvalid<=1;
     case(read_address)
      8'hd0:rx_rdata<={24'd0,3'd0,rx_flags[0],mailbox,frame_type}|(rx_flags[1]?32'h100:0);
      8'hd4:rx_rdata<={5'd0,rx_length,2'd0,rx_length,3'd0};
      8'hd8:rx_rdata<=({21'd0,rx_length}+3)>>2;
      8'hdc:begin rx_rdata<=rx_word;read_index<=read_index+1'b1;if(!mailbox||read_index>=(({21'd0,rx_length}+3)>>2))errors[7]<=1;end
      default:rx_rdata<=0;
     endcase
    end
   end
   if(rx_active&&!sent&&!rx_stop)begin
    age<=age+1'b1;
    if(age==sync_delay)begin rx_sync_valid<=1;rx_sync_slot<=now_slot;rx_sync_fine<=now_fine;end
    if(age==mail_delay)begin mailbox<=1;rx_irq<=1;sent<=1;rx_frames<=rx_frames+1'b1;end
   end
   if(rx_stop)rx_active<=0;
  end
 end
endmodule
`default_nettype wire
