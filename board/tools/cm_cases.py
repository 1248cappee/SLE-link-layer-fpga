"""CM board programs. Same operations are executed by XSim and JTAG.

Oracles are precomputed by independent host cryptography libraries. Repeated
stress packets are identical public test vectors, not new messages reusing a
production nonce. No PHY/RF acceptance is implied.
"""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def extend(Case,fixture,complete,words,pattern):
 cases=[]
 for grid in range(5):
  for lead in (499,500,501):
   c=Case(f'cm_grid_{grid}_lead_{lead}');wire=fixture(c,0,17)
   c.w(0x600,8|grid);c.op(7,0x20100,20,(100<<16)|(5<<11));c.op(13,0x604,0,0);c.op(8,0,lead,0)
   if lead<500:c.event(3)
   else:complete(c,0,17,wire)
   c.finish();cases.append(c)
  c=Case(f'cm_grid_{grid}_misaligned');fixture(c,0,17)
  c.w(0x600,8|grid);c.op(7,0x20100,20,(100<<16)|(5<<11));c.op(13,0x604,0,0)
  c.w(0x608,101);c.op(8,0,1000,0);c.event(5);c.finish();cases.append(c)
 oracle=[int(x,16) for x in (ROOT/'verification/cm_slot_nonce.mem').read_text().split()]
 for alg in (1,2):
  for mode in (0,1):
   c=Case(f'cm_slot_nonce_alg_{alg}_mode_{mode}')
   fixture(c,mode,17,alg)
   wire=b''.join(v.to_bytes(4,'little') for v in oracle[(alg-1)*512:alg*512])[:21]
   for i,v in enumerate(words(wire)):c.wr(0x49000+i*4,v)
   c.w(0x110,0);c.w(0x40,0);c.w(0x44,0);c.w(0xe0,0x200);c.w(0x110,1)
   c.w(0x600,0x100);c.w(0x60c,0)
   c.w(0x20100,(100<<16)|(5<<11)|mode);c.w(0x20104,0);c.w(0x20100,(100<<16)|(5<<11)|8|mode,3)
   complete(c,mode,17,wire,alg);c.finish();cases.append(c)
 for alg in (1,2):
  c=Case(f'cm_software_ccm_alg_{alg}');fixture(c,0,17,alg)
  for a,v in [(0x5000,(17<<16)|0x8000),(0x5004,(260<<16)|0x8800),
              (0x5008,0x03020100),(0x500c,0x07060504),(0x5010,0x0b0a0908),
              (0x5014,12),(0x5018,0),(0x501c,0)]:c.mw(a,v)
  for a,v in [(0xb4,0x0c0d0e0f),(0xb8,0x08090a0b),(0xbc,0x04050607),(0xc0,0x00010203),(0xc4,0x2800)]:c.w(a,v)
  c.w(0xb0,1|((alg-1)<<1));c.poll(0xb0,2,7);c.ck(0x25018,29,31)
  reference=[int(x,16) for x in (ROOT/'verification/aes_sm4_ccm.mem').read_text().split()]
  for i in range(6):c.ck(0x31000+i*4,reference[((alg-1)*8+4)*512+i],0xff if i==5 else 0xffffffff)
  c.finish();cases.append(c)
 for name,duration,external in [('timer',600,False),('external',2000,True),('software',2000,False)]:
  c=Case('cm_sleep_'+name);c.wr(0x40084,200 if external else 0)
  c.w(0x25000,0x11223344);c.w(0x034,duration);c.w(0x030,3);c.poll(0x508,3,15)
  if name=='software':c.w(0x030,4)
  else:c.op(2,0x25000,0,0,err=True)
  c.poll(0x508,0,15);c.ck(0x25000,0x11223344);c.ck(0x510,1);c.ck(0x514,1)
  c.finish();cases.append(c)
 c=Case('cm_sleep_10000')
 # Check the complete retained EM, not only a sentinel word. ETPTR is reset
 # to NULL, so this fill cannot publish an ownership object.
 retention_seed=0x12345678^0x25000
 c.op(10,0x20000,retention_seed,32768);c.w(0x60,0x1f);c.w(0x034,600)
 start=len(c.code);c.op(15);c.w(0x030,3);c.poll(0x508,3,15);c.op(16);c.op(3,0,20,0);c.op(16,0,1,0);c.op(2,0x25000,0,0,err=True)
 c.poll(0x508,0,15);c.op(15,0,1,0);c.op(17);c.ck(0x25000,0x12345678);c.op(12,start,10000,0)
 c.ck(0x510,10000);c.ck(0x514,10000)
 c.op(11,0x20000,retention_seed,32768);c.finish();cases.append(c)
 c=Case('cm_sleep_day_wrap');c.w(0x40,240);c.w(0x44,0x3fffffff);c.w(0xe0,0x200)
 c.w(0x034,1000);c.w(0x030,3);c.poll(0x508,0,15);c.ck(0x568,0x401,0x7ff)
 c.finish();cases.append(c)
 for kind in ('denied','withdrawn'):
  c=Case('cm_coex_'+kind);fixture(c,0,17)
  c.w(0x150,1)
  if kind=='denied':c.w(0x154,63)
  else:c.wr(0x40070,1|(31<<8));c.wr(0x40074,100)
  c.publish()
  if kind=='denied':c.event(3)
  else:c.event(1);c.event(6);c.event(4)
  c.check.append((0x40060,0,0xffffffff));c.finish();cases.append(c)
 c=Case('cm_coex_delayed_grant');fixture(c,0,17);c.wr(0x40070,4|(31<<8));c.wr(0x40074,1000)
 c.w(0x150,1);c.publish();c.event(1);c.event(6);c.event(2);c.finish();cases.append(c)
 c=Case('cm_sleep_unsafe_rejected');fixture(c,0,17);c.w(0x034,600);c.publish()
 c.op(1,0x030,3,0,err=True);c.event(1);c.event(6);c.event(2);c.ck(0x510,0);c.finish();cases.append(c)
 # Recovery pairs deliberately retain LL/tester state between the two tasks.
 # Mailbox ACK count must become two, proving that a reset did not substitute
 # for error-frame recovery. Failed MIC does not consume the RX payload count.
 for label,alg,crc,tamper in [('crc',0,False,False),('aes_mic',1,True,True),('sm4_mic',2,True,True)]:
  c=Case('cm_recovery_'+label+'_error');wire=fixture(c,1,17,alg,crc=crc,tamper=tamper)
  c.publish(1);complete(c,1,17,wire,alg,crc=crc,tamper=tamper);c.finish();cases.append(c)
  c=Case('cm_recovery_'+label+'_next');wire=fixture(c,1,17,alg)
  c.no_reset=True;c.setup=[entry for entry in c.setup if entry!=(0x40014,4,15)]
  c.publish(1);complete(c,1,17,wire,alg)
  c.check=[(a,2 if a==0x40064 else v,m) for a,v,m in c.check]
  c.finish();cases.append(c)
 c=Case('cm_mixed_grid_competition_16');fixture(c,0,17)
 for e in range(1,16):
  for off,v in [(0,9),(0x18,20),(0x20,0x1800),(0x24,0x1c00),(0x58,76)]:c.wr(0x800+e*128+off,v)
  c.mw(0x108+e*16,0x200)
 c.op(7,0x20100,20,100<<16)
 for e in range(16):
  c.w(0x600+e*16,8|(e%5));c.op(13,0x604+e*16,0,0)
 for e in range(16):c.op(9,0x20100+e*16,0,(100<<16)|(e<<11))
 c.op(3,0,150000,0)
 for e in range(16):c.ck(0x20100+e*16,(4 if e==15 else 5)<<3,0x38)
 c.ck(0x24,18,255);c.check.append((0x40068,1,0xffffffff))
 c.check.append((0xffffff00,0xffff,15));c.finish();cases.append(c)
 return cases

def pressure(Case,fixture,complete,words,pattern,seconds=1800):
 c=Case('cm_pressure_30min');fixture(c,0,17,1)
 c.wr(0x40088,1);c.wr(0x40070,1|(31<<8));c.wr(0x40074,100)
 # Six tasks per iteration: four secure modes, cancellation, coex withdrawal.
 start=len(c.code)
 for mode in (0,1,2,3):
  c.w(0x22000,0);c.w(0x22800,0);c.w(0x23804,2047<<16)
  c.w(0x20400,0x30|mode);c.w(0x800,9|((0 if mode==0 else 2 if mode==2 else 3)<<20)|(1<<16))
  c.publish(mode);c.event(1)
  for kind in ([6] if mode==0 else [7] if mode==1 else [6,7] if mode==2 else [7,6]):c.event(kind)
  c.event(2);c.w(0x20100,0)
  if mode!=0:
   c.ck(0x2380c,31,31)
   for i,v in enumerate(words(pattern(17))):c.ck(0x30800+i*4,v,0xff if i==4 else 0xffffffff)
 c.w(0x22000,0);c.w(0x20400,0x30);c.w(0x800,9|(1<<16));c.publish(0)
 c.w(0x110,0x101);c.event(4);c.w(0x20100,0)
 c.w(0x22000,0);c.w(0x150,1);c.publish(0);c.event(1);c.event(6);c.event(4);c.w(0x20100,0);c.w(0x150,0)
 c.op(15);c.w(0x034,600);c.w(0x030,3);c.poll(0x508,3,15);c.op(16);c.op(3,0,20,0);c.op(16,0,1,0);c.poll(0x508,0,15);c.op(15,0,1,0);c.op(17)
 cycles=int(seconds*20000000)
 c.op(14,start,cycles&0xffffffff,cycles>>32)
 c.ck(0x24,0,255);c.finish()
 c.check.append((0x40060,0,0xffffffff));c.check.append((0x4008c,0xffff,0xffff))
 return c
