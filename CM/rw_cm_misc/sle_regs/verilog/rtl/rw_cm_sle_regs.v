`default_nettype none
// SLE CM ABI 1.1. This bank owns only previously undefined legacy aliases and
// the explicit 0x540..0x6ff extension; original EM layouts remain unchanged.
module rw_cm_sle_regs(
 input wire clk,rst_n,req,write,
 input wire [11:0] addr,
 input wire [31:0] wdata,
 input wire [3:0] be,
 output reg ack,error,bad_cmd,
 output reg [31:0] rdata,
 input wire [15:0] owned,
 input wire [3:0] context_index,
 output wire [127:0] cm_context,
 output wire [2047:0] cm_banks,
 input wire [9:0] day_count,
 input wire day_valid,
 input wire [15:0] time_generation,
 input wire [16:0] diag_min,diag_max,
 input wire [31:0] diag_reads,diag_writes,diag_waits,diag_faults,diag_first,
 input wire [3:0] diag_first_info,
 input wire [3:0] event_set,
 output wire cm_irq,
 output reg diag_clear,diag_freeze,
 output reg coex_enable,
 output reg [4:0] coex_peer_priority,
 output reg coex_peer_busy,
 output reg [31:0] sw_key0,sw_key1,sw_key2,sw_key3,
 output reg [15:0] sw_ptr,
 output reg sw_start,
 output reg [2:0] sw_mode,
 input wire sw_busy,sw_done,sw_error,
 input wire [31:0] sw_result
);
 reg held,sw_completed,sw_failed;
 reg [31:0] banks[0:63];
 reg [3:0] interrupt_status,interrupt_mask;
 reg [31:0] old_value,merged;
 reg invalid;
 integer i,b;
 wire [5:0] index=addr[7:2];
 wire [3:0] et_index=addr[7:4];
 genvar k;
 generate for(k=0;k<64;k=k+1)begin: bank_outputs
  assign cm_banks[k*32+:32]=banks[k];
 end endgenerate
 assign cm_context=cm_banks[{context_index,7'b0}+:128];
 assign cm_irq=|(interrupt_status&interrupt_mask);
 always @* begin
  old_value=0;
  if(addr[11:8]==6) old_value=banks[index];
  else case(addr)
   12'h050,12'h540:old_value={30'd0,diag_freeze,1'b0};
   12'h150:old_value={31'd0,coex_enable};
   12'h154:old_value={26'd0,coex_peer_priority,coex_peer_busy};
   12'h578:old_value={28'd0,interrupt_mask};
   12'h0b4:old_value=sw_key0;12'h0b8:old_value=sw_key1;
   12'h0bc:old_value=sw_key2;12'h0c0:old_value=sw_key3;
   12'h0c4:old_value={16'd0,sw_ptr};
   default:old_value=0;
  endcase
  merged=old_value;
  for(b=0;b<4;b=b+1)if(be[b])merged[b*8+:8]=wdata[b*8+:8];
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   held<=0;sw_completed<=0;sw_failed<=0;ack<=0;error<=0;bad_cmd<=0;rdata<=0;
   diag_clear<=0;diag_freeze<=0;coex_enable<=0;coex_peer_busy<=0;coex_peer_priority<=0;
   interrupt_status<=0;interrupt_mask<=0;sw_key0<=0;sw_key1<=0;sw_key2<=0;sw_key3<=0;
   sw_ptr<=0;sw_start<=0;sw_mode<=0;
   for(i=0;i<64;i=i+1)banks[i]<=0;
  end else begin
   ack<=0;error<=0;bad_cmd<=0;diag_clear<=0;sw_start<=0;
   interrupt_status<=interrupt_status|event_set;
   if(sw_done)begin sw_completed<=1;sw_failed<=sw_error;end
   if(!req)held<=0;
   if(req&&!held)begin
    held<=1;ack<=1;rdata<=0;invalid=addr[1:0]!=0;
    if(!write)begin
     if(addr[11:8]==6)rdata<=banks[index];
     else case(addr)
      12'h050,12'h540:rdata<={30'd0,diag_freeze,1'b0};
      12'h054:rdata<={28'd0,interrupt_status};
      12'h544:rdata<=32'h00010001;
      12'h548:rdata<=diag_reads;12'h54c:rdata<=diag_writes;
      12'h550:rdata<=diag_waits;12'h554:rdata<=diag_faults;
      12'h558:rdata<={15'd0,diag_min};12'h55c:rdata<={15'd0,diag_max};
      12'h560:rdata<=diag_first;12'h564:rdata<={28'd0,diag_first_info};
      12'h568:rdata<={21'd0,day_valid,day_count};
      12'h56c:rdata<={16'd0,time_generation};
      12'h574:rdata<={28'd0,interrupt_status};12'h578:rdata<={28'd0,interrupt_mask};
      12'h150:rdata<={31'd0,coex_enable};
      12'h154:rdata<={26'd0,coex_peer_priority,coex_peer_busy};
      12'h158:rdata<=0;
      12'h0b0:rdata<={29'd0,sw_failed,sw_completed,sw_busy};
      12'h0b4:rdata<=sw_key0;12'h0b8:rdata<=sw_key1;
      12'h0bc:rdata<=sw_key2;12'h0c0:rdata<=sw_key3;
      12'h0c4:rdata<={16'd0,sw_ptr};12'h57c:rdata<=sw_result;
      default:invalid=1;
     endcase
    end else if(!invalid)begin
     if(addr[11:8]==6)begin
      if(owned[et_index])invalid=1;
      else case(addr[3:2])
       0:if((merged&32'hfffffef0)!=0 || merged[2:0]>4)invalid=1;
         else banks[index]<=merged;
       1:if(merged[31:30]!=0)invalid=1;else banks[index]<=merged;
       2:if(merged>249)invalid=1;else banks[index]<=merged;
       3:if(merged!=0)invalid=1;else banks[index]<={16'd0,time_generation};
      endcase
     end else case(addr)
      12'h050,12'h540:if(merged[31:2]!=0)invalid=1;else begin
       diag_freeze<=merged[1];if(be[0]&&wdata[0])diag_clear<=1;
      end
      12'h574:if(merged[31:4]!=0)invalid=1;else interrupt_status<=(interrupt_status&~merged[3:0])|event_set;
      12'h578:if(merged[31:4]!=0)invalid=1;else interrupt_mask<=merged[3:0];
      12'h150:if(merged[31:1]!=0 || owned!=0)invalid=1;else coex_enable<=merged[0];
      12'h154:if(merged[31:6]!=0 || owned!=0)invalid=1;else begin coex_peer_priority<=merged[5:1];coex_peer_busy<=merged[0];end
      12'h158:if(merged!=0)invalid=1;
      12'h0b4,12'h0b8,12'h0bc,12'h0c0,12'h0c4:begin
       if(sw_busy || owned!=0)invalid=1;
       else case(addr)
        12'h0b4:sw_key0<=merged;12'h0b8:sw_key1<=merged;
        12'h0bc:sw_key2<=merged;12'h0c0:sw_key3<=merged;
        12'h0c4:if(merged[31:16]!=0||merged[0])invalid=1;else sw_ptr<=merged[15:0];
       endcase
      end
      12'h0b0:if((merged&32'hfffffff0)!=0 || !be[0] || sw_busy || owned!=0)invalid=1;
        else if(wdata[0])begin sw_start<=1;sw_mode<=wdata[3:1];sw_completed<=0;sw_failed<=0;end
      default:invalid=1;
     endcase
    end
    if(invalid)begin error<=1;bad_cmd<=1;end
   end
  end
 end
endmodule
`default_nettype wire
