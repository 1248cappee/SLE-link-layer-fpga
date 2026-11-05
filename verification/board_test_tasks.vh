 task wr(input [18:0] a,input [31:0] v);reg [31:0] q;bus(1,a,v,15,q);endtask
 task rd(input [18:0] a,output [31:0] q);bus(0,a,0,15,q);endtask
 task mw(input integer a,input [31:0] v);wr(18'h20000+a,v);endtask
 task mh(input integer a,input [15:0] v);reg [31:0] q;bus(1,18'h20000+(a&~3),a%4==0?{16'd0,v}:{v,16'd0},a%4==0?3:12,q);endtask
 task mr(input integer a,output [31:0] q);rd(18'h20000+a,q);endtask
 task event_get(input integer kind,input integer idx);
  do rd('h24,head);while(head[7:0]==0);
  if(head[15:12]!=kind||head[11:8]!=idx)$fatal(1,"event expected type=%0d idx=%0d got=%h, error=%h",kind,idx,head,dut.debug_errors);
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
  target=dut.debug_slot+20;target_fine_expect=0;
  mw('h100,(target[15:0]<<16)|(5<<11)|md);
  mw('h104,{16'd0,2'd0,target[29:16]});mw('h108,'h400/2);mw('h10c,0);
  if(publish)mh('h100,(5<<11)|8|md);
 endtask
