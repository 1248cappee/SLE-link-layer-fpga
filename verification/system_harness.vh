 `include "system_ports.vh"
 rw_ble_top dut(.*);
 integer cycles=0,tx_received=0,air_left=0,rx_age=0,rx_reads=0;
 integer expected_length=17,rx_test_length=17,air_ticks=40;
 integer oracle_case=0,target_fine_expect=0;
 bit secure_payload=0,tamper_mic=0;
 reg [31:0] security_oracle[0:8191];
 initial $readmemh("aes_sm4_ccm.mem",security_oracle);
 bit rx_active=0,mailbox=0,rx_sent=0,good_crc=1,duplicate_frame=0;
 reg [2:0] frame_type=1;
 reg [31:0] d,head;
 integer i,j,mode_test;
 reg [29:0] target;
 reg [31:0] x;
 function [7:0] pattern(input integer n);pattern=(n*37+11)&255;endfunction
 function [7:0] wire_byte(input integer n);
  wire_byte=secure_payload?security_oracle[oracle_case*512+n/4][(n%4)*8+:8]:pattern(n);
  if(tamper_mic&&n==rx_test_length-1)wire_byte=wire_byte^1;
 endfunction
 // Independent transaction-level PHY contract model. It implements no IQ,
 // modulation, FEC or RF and is not reported as real-PHY acceptance.
 always @(posedge clk) begin
  if(!rst_n) begin
   cycles<=0;tx_received<=0;tx_prepared<=0;tx_air_started<=0;tx_air_done<=0;tx_quiescent<=1;air_left<=0;
   rx_rvalid<=0;rx_irq<=0;rx_window_started<=0;rx_sync_valid<=0;rx_drain_done<=1;
   rx_active<=0;mailbox<=0;rx_sent<=0;rx_age<=0;rx_reads<=0;
  end else begin
   cycles<=cycles+1;tx_cfg_ready<=cycles%5!=0;tx_ready<=cycles%7!=0;
   tx_air_started<=0;tx_air_done<=0;rx_rvalid<=0;rx_window_started<=0;rx_sync_valid<=0;
   if(tx_cfg_valid&&tx_cfg_ready) begin
    if(tx_payload_bytes!=expected_length)$fatal(1,"TX length %d expected %d",tx_payload_bytes,expected_length);
    tx_received<=0;tx_prepared<=tx_payload_bytes==0;tx_quiescent<=0;
   end
   if(tx_valid&&tx_ready) begin
    for(integer b=0;b<4;b=b+1) if(tx_keep[b]) begin
     if(tx_data[b*8+:8]!==wire_byte(tx_received+b))$fatal(1,"TX data byte %0d got %h",tx_received+b,tx_data);
    end
    tx_received<=tx_received+$countones(tx_keep);
    if(tx_last) begin
     if(tx_received+$countones(tx_keep)!=expected_length)$fatal(1,"TX last/keep mismatch");tx_prepared<=1;
    end
   end
   if(tx_launch) begin
    if(!tx_prepared)$fatal(1,"launch before prepared");
    tx_air_started<=1;tx_start_slot<=dut.now_slot;tx_start_fine<=dut.now_fine;air_left<=air_ticks*10;
   end
   if(air_left>0) begin
    air_left<=air_left-1;if(air_left==1)begin tx_air_done<=1;tx_quiescent<=1;tx_prepared<=0;end
   end
   if(tx_stop)begin tx_prepared<=0;tx_quiescent<=1;air_left<=0;end
   if(rx_req) begin
    if(rx_write) begin
     case(rx_addr)
      8'h04:frame_type<=rx_wdata[2:0];
      8'h3c:if(rx_wdata[0])begin mailbox<=0;rx_irq<=0;end
      8'h00:begin
       rx_active<=rx_wdata[0];
       if(rx_wdata[1])begin rx_window_started<=1;rx_sent<=0;rx_age<=0;rx_reads<=0;end
       if(rx_wdata[31]&&!mailbox)rx_irq<=0;
      end
     endcase
    end else begin
     rx_rvalid<=1;
     case(rx_addr)
      8'hd0:rx_rdata<={24'd0,1'b0,1'b0,1'b0,good_crc,mailbox,frame_type}|(duplicate_frame?32'h100:0);
      8'hd4:rx_rdata<=(rx_test_length<<16)|(rx_test_length*8);
      8'hd8:rx_rdata<=(rx_test_length+3)/4;
      8'hdc:begin
       if(!mailbox||rx_reads>=(rx_test_length+3)/4)$fatal(1,"duplicate/out of bounds mailbox read");
       for(integer b=0;b<4;b=b+1)rx_rdata[b*8+:8]<=wire_byte(rx_reads*4+b);
       rx_reads<=rx_reads+1;
      end
      default:rx_rdata<=0;
     endcase
    end
   end
   if(rx_active&&!rx_sent)begin
    rx_age<=rx_age+1;
    if(rx_age==20)begin rx_sync_valid<=1;rx_sync_slot<=dut.now_slot;rx_sync_fine<=dut.now_fine;end
    if(rx_age==100)begin mailbox<=1;rx_irq<=1;rx_sent<=1;end
   end
   rx_drain_done<=!rx_active&&!mailbox;
  end
 end
 task bus(input bit wr,input [17:0] address,input [31:0] value,input [3:0] ben,output [31:0] result,input bit expected_error=0);
  @(negedge clk);p_ad=address;p_wdata=value;p_ben=ben;p_wr=wr;p_rd=!wr;
  do begin @(posedge clk);#1;end while(p_wait);
  result=p_rdata;
  if(p_error!==expected_error)$fatal(1,"bus error addr=%h actual=%b expected=%b",address,p_error,expected_error);
  @(negedge clk);p_wr=0;p_rd=0;
  @(negedge clk);
 endtask
 task wr(input [17:0] a,input [31:0] v);reg [31:0] q;bus(1,a,v,15,q);endtask
 task rd(input [17:0] a,output [31:0] q);bus(0,a,0,15,q);endtask
 task mw(input integer a,input [31:0] v);wr(18'h20000+a,v);endtask
 task mh(input integer a,input [15:0] v);reg [31:0] q;bus(1,18'h20000+(a&~3),a%4==0?{16'd0,v}:{v,16'd0},a%4==0?3:12,q);endtask
 task mr(input integer a,output [31:0] q);rd(18'h20000+a,q);endtask
 task event_get(input integer kind,input integer idx);
  do rd('h24,head);while(head[7:0]==0);
  if(head[15:12]!=kind||head[11:8]!=idx)$fatal(1,"event expected type=%0d idx=%0d got=%h, error=%h",kind,idx,head,dut.error_status);
  rd('h24,d);if(d!==head)$fatal(1,"event head moved without POP");
  if(kind==1)begin
   rd('h114,d);if(d[29:0]!=target)$fatal(1,"actual start slot %h expected %h",d,target);
   rd('h118,d);if(d[9:0]!=target_fine_expect)$fatal(1,"actual start fine %d expected %d",d,target_fine_expect);
  end
  wr('h110,'h201);
 endtask
 task configure(input integer md,input integer n,input bit odd_half=0,input bit publish=1);
  expected_length=n;rx_test_length=n;tx_received=0;
  for(i=0;i<37;i=i+1)mw('h400+i*4,0);
  mw('h400,'h30|md);
  mw('h420,('h2800/2)<<16);mw('h424,'h2000/2);
  mw('h42c,0);mw('h430,1000);mw('h438,(200<<16)|2047);
  mw('h41c,(200<<16));
  for(i=0;i<4;i=i+1)mw('h2000+i*4,0);
  mw('h2004,('h10000+(odd_half?2:0))/2);
  for(i=0;i<7;i=i+1)mw('h2800+i*4,0);
  mw('h2814,('h10800+(odd_half?2:0))/2);
  mw('h3000,'h2000/2);mw('h3004,(2047<<16)|n);mw('h3008,air_ticks);mw('h300c,0);
  mw('h3800,'h2800/2);mw('h3804,(2047<<16));mw('h3808,0);mw('h380c,0);
  for(i=0;i<(n+3)/4;i=i+1)begin
   x=0;for(j=0;j<4;j=j+1)if(i*4+j<n)x[j*8+:8]=pattern(i*4+j);
   if(!odd_half)mw('h10000+i*4,x);
   else begin mh('h10002+i*4,x[15:0]);mh('h10004+i*4,x[31:16]);end
  end
  wr('h800,(n<=251?(1|(1<<3)):(2|(2<<3)))|((md==0?0:md==2?2:3)<<20));wr('h818,n<=251?20:28);wr('h820,'h3000/2);wr('h824,'h3800/2);wr('h858,76);
  target=dut.now_slot+20;target_fine_expect=0;
  mw('h100,(target[15:0]<<16)|(5<<11)|md);
  mw('h104,{16'd0,2'd0,target[29:16]});mw('h108,'h400/2);mw('h10c,0);
  if(publish)mh('h100,(5<<11)|8|md);
 endtask
