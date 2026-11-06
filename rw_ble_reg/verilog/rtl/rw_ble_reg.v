`default_nettype none
module rw_ble_reg #(parameter integer EM_BYTES=131072, FIFO_DEPTH=64)(
 input wire clk,rst_n,
 input wire req,write,
 input wire [11:0] addr,
 input wire [31:0] wdata,
 input wire [3:0] be,
 output reg ack,error,
 output reg [31:0] rdata,
 input wire busy,scheduler_idle,
 input wire [15:0] owned,
 input wire [29:0] live_slot,snap_slot,
 input wire [9:0] live_fine,snap_fine,
 input wire [2:0] armed,
 input wire [5:0] int_status,
 input wire [4:0] error_status,
 input wire [71:0] head_event,
 input wire [7:0] fifo_count,
 input wire [31:0] phy_caps,
 input wire [3:0] context_index,
 output wire [1023:0] context_data,
 output reg enable,schedule_enable,
 output reg [13:0] etptr,
 output reg [5:0] int_mask,int_ack,
 output reg [4:0] error_ack,
 output reg bad_cmd,soft_reset,fifo_pop,cancel,
 output reg [3:0] cancel_index,
 output reg snap,load_time,arm_we,
 output reg [2:0] arm_data,
 output reg [29:0] load_slot,
 output reg [9:0] load_fine,
 output wire [89:0] target_slots,
 output wire [29:0] target_fines
);
 reg held;
 reg [31:0] target_slot[0:2];
 reg [31:0] target_fine[0:2];
 reg [31:0] ext[0:511];
 reg [31:0] merged,old_value;
 reg invalid;
 integer i,b;
 wire [8:0] ext_word=addr[10:2];
 wire [3:0] ext_index=addr[10:7];
 wire [3:0] event_type=head_event[7:4];
 wire [29:0] event_slot=head_event[45:16];
 wire [9:0] event_fine=head_event[55:46];
 wire event_end=event_type==2 || event_type==4 || event_type==5 || event_type==6 || event_type==7;
 genvar k;
 generate for(k=0;k<32;k=k+1) begin: context_mux
  assign context_data[k*32+:32]=ext[{context_index,5'b00000}+k];
 end endgenerate
 assign target_slots={target_slot[2][29:0],target_slot[1][29:0],target_slot[0][29:0]};
 assign target_fines={target_fine[2][9:0],target_fine[1][9:0],target_fine[0][9:0]};
 always @* begin
  old_value=0;
  if(addr[11]) old_value=ext[ext_word];
  else case(addr)
   12'h000:old_value={31'd0,enable};
   12'h00c:old_value={26'd0,int_mask};
   12'h02c:old_value={18'd0,etptr};
   12'h040:old_value={22'd0,load_fine};
   12'h044:old_value={2'd0,load_slot};
   12'h0e0:old_value={29'd0,armed};
   12'h0e8:old_value=target_slot[0];12'h0ec:old_value=target_fine[0];
   12'h0f0:old_value=target_slot[1];12'h0f4:old_value=target_fine[1];
   12'h0f8:old_value=target_slot[2];12'h0fc:old_value=target_fine[2];
   12'h110:old_value={24'd0,cancel_index,3'd0,schedule_enable};
   default:old_value=0;
  endcase
  merged=old_value;
  for(b=0;b<4;b=b+1) if(be[b]) merged[b*8+:8]=wdata[b*8+:8];
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   held<=0;ack<=0;error<=0;rdata<=0;enable<=0;schedule_enable<=0;etptr<=0;
   int_mask<=0;int_ack<=0;error_ack<=0;bad_cmd<=0;soft_reset<=0;fifo_pop<=0;cancel<=0;cancel_index<=0;
   snap<=0;load_time<=0;arm_we<=0;arm_data<=0;load_slot<=0;load_fine<=0;
   for(i=0;i<3;i=i+1) begin target_slot[i]<=0;target_fine[i]<=0;end
   for(i=0;i<512;i=i+1) ext[i]<=0;
  end else begin
   ack<=0;error<=0;int_ack<=0;error_ack<=0;bad_cmd<=0;soft_reset<=0;fifo_pop<=0;cancel<=0;
   snap<=0;load_time<=0;arm_we<=0;
   if(!req) held<=0;
   if(req && !held) begin
    held<=1;ack<=1;invalid=addr[1:0]!=0;rdata<=0;
    if(!write) begin
     if(addr[11]) rdata<=ext[ext_word];
     else case(addr)
      12'h000:rdata<={23'd0,busy,7'd0,enable};
      12'h004:rdata<=32'h534c0100;
      12'h008:rdata<=32'h00100f01; // SLE ABI 1, 16 ET, mode mask 0xf
      12'h00c:rdata<={26'd0,int_mask};
      12'h010:rdata<={26'd0,int_status};
      12'h024:rdata<={8'd0,head_event[15:8],head_event[7:4],head_event[3:0],fifo_count};
      12'h028:rdata<=event_type==7?{18'd0,head_event[69:56]}:0;
      12'h02c:rdata<={18'd0,etptr};
      12'h040:rdata<={22'd0,load_fine};12'h044:rdata<={2'd0,load_slot};
      12'h060:rdata<={27'd0,error_status};
      12'h0e0:rdata<={29'd0,armed};
      12'h0e8:rdata<=target_slot[0];12'h0ec:rdata<=target_fine[0];
      12'h0f0:rdata<=target_slot[1];12'h0f4:rdata<=target_fine[1];
      12'h0f8:rdata<=target_slot[2];12'h0fc:rdata<=target_fine[2];
      12'h100:rdata<={2'd0,snap_slot};12'h104:rdata<={22'd0,snap_fine};
      12'h110:rdata<={24'd0,cancel_index,3'd0,schedule_enable};
      12'h114:rdata<=event_type==1?{2'd0,event_slot}:0;
      12'h118:rdata<=event_type==1?{22'd0,event_fine}:0;
      12'h11c:rdata<=event_end?{2'd0,event_slot}:0;
      12'h120:rdata<=event_end?{22'd0,event_fine}:0;
      12'h124:rdata<=event_type==3?{2'd0,event_slot}:0;
      12'h128:rdata<=event_type==3?{22'd0,event_fine}:0;
      12'h400:rdata<=32'h534c4558; // SLEX
      12'h404:rdata<=32'h00010001;
      12'h408:rdata<=EM_BYTES;12'h40c:rdata<=FIFO_DEPTH;
      12'h410:rdata<=phy_caps;12'h414:rdata<=32'h1e00fa7d;
      // Undefined legacy fields are RAZ/W0, not invented BLE behavior.
      default:rdata<=0;
     endcase
    end else if(!invalid) begin
     if(addr[11]) begin
      if(owned[ext_index]) invalid=1;
      else ext[ext_word]<=merged;
     end else case(addr)
      12'h000: begin
       if((merged & ~32'h00000003)!=0) invalid=1;
       else begin enable<=merged[0];if(be[0]&&wdata[1]) soft_reset<=1;end
      end
      12'h00c:if(merged[31:6]!=0) invalid=1;else int_mask<=merged[5:0];
      12'h014:begin
       if((merged & ~32'h0000002e)!=0) invalid=1;
       else int_ack<=merged[5:0];
      end
      12'h02c:begin
       if(!scheduler_idle || fifo_count!=0 || merged[31:14]!=0 || merged[2:0]!=0 ||
          ({1'b0,merged[13:0],1'b0}+256)>EM_BYTES || ({1'b0,merged[13:0],1'b0}+256)>32768 || merged[13:0]==0) invalid=1;
       else etptr<=merged[13:0];
      end
      12'h040:if(merged>249) invalid=1;else load_fine<=merged[9:0];
      12'h044:if(merged[31:30]!=0) invalid=1;else load_slot<=merged[29:0];
      12'h060:if(merged[31:5]!=0) invalid=1;else error_ack<=merged[4:0];
      12'h0e0:begin
       if((merged & ~32'h00000307)!=0 ||
          (merged[9] && (busy || !scheduler_idle || schedule_enable || armed!=0 || merged[2:0]!=0))) invalid=1;
       else begin
        if(be[0]) begin arm_we<=1;arm_data<=merged[2:0];end
        if(be[1]&&wdata[8]) snap<=1;
        if(be[1]&&wdata[9]) load_time<=1;
       end
      end
      12'h0e8:if(armed[0]||merged[31:30]!=0) invalid=1;else target_slot[0]<=merged;
      12'h0ec:if(armed[0]||merged>249) invalid=1;else target_fine[0]<=merged;
      12'h0f0:if(armed[1]||merged[31:30]!=0) invalid=1;else target_slot[1]<=merged;
      12'h0f4:if(armed[1]||merged>249) invalid=1;else target_fine[1]<=merged;
      12'h0f8:if(armed[2]||merged[31:30]!=0) invalid=1;else target_slot[2]<=merged;
      12'h0fc:if(armed[2]||merged>249) invalid=1;else target_fine[2]<=merged;
      12'h110:begin
       if((merged & ~32'h000003f1)!=0) invalid=1;
       else begin
        schedule_enable<=merged[0];cancel_index<=merged[7:4];
        if(be[1]&&wdata[8]) cancel<=1;
        if(be[1]&&wdata[9]) begin if(fifo_count==0) invalid=1;else fifo_pop<=1;end
       end
      end
      default:if(merged!=0) invalid=1;
     endcase
    end
    if(invalid) begin error<=1;bad_cmd<=1;end
   end
  end
 end
endmodule
`default_nettype wire
