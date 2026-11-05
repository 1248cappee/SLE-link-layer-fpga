"""One set of board scenarios for XSim and JTAG; independent byte oracles."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'board/cases'
MASK=0xffffffff
def pattern(n):return bytes((i*37+11)&255 for i in range(n))
def words(b):return [int.from_bytes(b[i:i+4].ljust(4,b'\0'),'little') for i in range(0,len(b),4)]
class Case:
    def __init__(self,name):self.name=name;self.setup=[(0x40014,4,15)];self.code=[];self.check=[]
    def wr(self,a,v,be=15):self.setup.append((a,v&MASK,be))
    def mw(self,a,v):self.wr(0x20000+a,v)
    def op(self,op,a=0,v=0,m=MASK,be=15,err=False):self.code.append((op|(be<<8)|(int(err)<<16),a,v&MASK,m&MASK))
    def w(self,a,v,be=15):self.op(1,a,v,0,be)
    def ck(self,a,v,m=MASK):self.op(2,a,v,m)
    def poll(self,a,v,m=MASK):self.op(4,a,v,m)
    def event(self,kind,idx=0):
        self.poll(0x24,(kind<<12)|(idx<<8),0xff00)
        self.ck(0x24,(kind<<12)|(idx<<8),0xff00)
        self.w(0x110,0x201)
    def publish(self,md=0,lead=None):
        self.op(7 if lead is not None else 6,0x20100,20,(100<<16)|(5<<11)|md)
        if lead is not None:self.op(8,0,lead,0)
    def finish(self):self.op(0,0,0,0)
def fixture(c,md,n,alg=0,crc=True,duplicate=False,tamper=False,capacity=2047):
    wire=pattern(n)
    if alg:
        oracle=[int(x,16) for x in (ROOT/'verification/aes_sm4_ccm.mem').read_text().split()]
        ix=[0,1,15,16,17,31,260,2043].index(n)
        wire=b''.join(x.to_bytes(4,'little') for x in oracle[((alg-1)*8+ix)*512:((alg-1)*8+ix+1)*512])[:n+4]
    if tamper:wire=wire[:-1]+bytes([wire[-1]^1])
    c.wr(0x40010,1);c.wr(0x40040,len(wire));c.wr(0x40044,int(crc)|(int(duplicate)<<1));c.wr(0x40048,17)
    for i,w in enumerate(words(wire)):c.wr(0x49000+i*4,w)
    for e in range(16):
        for k in range(4):c.mw(0x100+e*16+k*4,0)
    for k in range(37):c.mw(0x400+k*4,0)
    c.mw(0x400,0x30|md);c.mw(0x420,(0x2800//2)<<16);c.mw(0x424,0x2000//2)
    c.mw(0x430,1000);c.mw(0x438,(200<<16)|2047);c.mw(0x41c,200<<16)
    for k in range(4):c.mw(0x2000+k*4,0)
    c.mw(0x2004,0x10000//2)
    for k in range(7):c.mw(0x2800+k*4,0)
    c.mw(0x2814,0x10800//2)
    c.mw(0x3000,0x2000//2);c.mw(0x3004,(capacity<<16)|n);c.mw(0x3008,40);c.mw(0x300c,0)
    c.mw(0x3800,0x2800//2);c.mw(0x3804,capacity<<16);c.mw(0x3808,0);c.mw(0x380c,0)
    for i,w in enumerate(words(pattern(n))):c.mw(0x10000+i*4,w)
    # Guard the byte immediately after the RX allocation.
    c.mw((0x10800+len(wire))&~3,0x5a5a5a5a)
    c.wr(0x800,(9 if n<=251 else 18)|((0 if md==0 else 2 if md==2 else 3)<<20)|(alg<<16))
    c.wr(0x818,20 if n<=251 else 28);c.wr(0x820,0x3000//2);c.wr(0x824,0x3800//2);c.wr(0x858,76)
    if alg:
        for a,v in [(0x830,0x0c0d0e0f),(0x834,0x08090a0b),(0x838,0x04050607),(0x83c,0x00010203),
          (0x840,0x08070605),(0x844,0x0c0b0a09),(0x848,0x03020100),(0x84c,4),(0x850,0),(0x828,0x03020100),(0x82c,4)]:c.wr(a,v)
    c.mw(0x108,0x400//2);c.mw(0x10c,0)
    c.wr(0x2c,0x80);c.wr(0xc,0x3f);c.wr(0,1);c.wr(0x110,1)
    return wire
def complete(c,md,n,wire,alg=0,crc=True,duplicate=False,tamper=False):
    c.event(1)
    for kind in ([6] if md==0 else [7] if md==1 else [6,7] if md==2 else [7,6]):c.event(kind)
    c.event(2)
    if md!=1:
        c.ck(0x22000,0x8000,0x8000)
        c.check.extend((0x48000+i*4,v,(1<<(8*min(4,len(wire)-i*4)))-1) for i,v in enumerate(words(wire)))
    if md!=0:
        outcome=1|(int(crc)<<1)|(int(alg!=0)<<2)|(int(alg!=0 and crc and not tamper)<<3)|(int(crc and not duplicate and not tamper)<<4)
        c.ck(0x2380c,outcome,31);c.ck(0x22800,0x8000,0x8000)
        expected=pattern(n) if alg and crc and not tamper else wire
        if not alg or (crc and not tamper):
            c.check.extend((0x30800+i*4,v,(1<<(8*min(4,len(expected)-i*4)))-1) for i,v in enumerate(words(expected)))
        if not alg:c.check.append((0x20000+((0x10800+n)&~3),0x5a<<((n%4)*8),0xff<<((n%4)*8)))
        c.check.append((0x40064,1,MASK))
    c.check.append((0x40060,0,MASK))
    c.ck(0x24,0,255)
def chain(c,count):
    c.mw(0x430,20000)
    for k in range(count):
        nxt=0 if k==count-1 else (0x2000+(k+1)*16)//2
        meta_nxt=0 if k==count-1 else (0x3000+(k+1)*16)//2
        for off,v in [(0,nxt),(4,0x10000//2),(8,0),(12,0)]:c.mw(0x2000+k*16+off,v)
        for off,v in [(0,(meta_nxt<<16)|((0x2000+k*16)//2)),(4,(2047<<16)|17),(8,40),(12,0)]:c.mw(0x3000+k*16+off,v)
def scenarios():
    cases=[]
    c=Case('foundation_full_em')
    offsets=[int(s,16) for s in (ROOT/'verification/register_offsets.mem').read_text().split()]
    for a in offsets:c.ck(a,0x534c0100 if a==4 else 0x00100f01 if a==8 else 0,MASK^32 if a==0x10 else MASK)
    for i in range(512):c.ck(0x800+i*4,0)
    c.ck(4,0x534c0100);c.ck(8,0x00100f01);c.ck(0x408,131072);c.ck(0x40c,64)
    for seed in (0xa5a55a5a,0x5a5aa5a5):c.op(10,0x20000,seed,32768);c.op(11,0x20000,seed,32768)
    c.w(0x25000,0x11223344);c.w(0x25000,0xaa000000,8);c.ck(0x25000,0xaa223344)
    c.op(2,0x18000,0,0,err=True);c.finish();cases.append(c)
    c=Case('register_time_irq')
    c.op(1,4,0x12345678,0,err=True);c.ck(4,0x534c0100);c.ck(0x60,16,16);c.w(0x60,16);c.ck(0x60,0)
    c.op(1,0x2c,1,0,err=True);c.w(0x60,16)
    c.w(0x40,100);c.w(0x44,7);c.w(0xe0,0x200);c.w(0xe0,0x100);c.ck(0x100,7)
    c.op(3,0,300,0);c.ck(0x100,7)
    for a in (0xe8,0xf0,0xf8):c.w(a,0);c.w(a+4,0)
    c.w(0xe0,7);c.op(3,0,30,0);c.ck(0xe0,0);c.ck(0x10,14,14);c.w(0x14,14);c.ck(0x10,0,14)
    c.op(1,0x110,0x200,0,err=True);c.ck(0x24,0);c.w(0x60,16)
    c.w(0x40,249);c.w(0x44,0x3fffffff);c.w(0xe0,0x200);c.op(3,0,30,0);c.w(0xe0,0x100);c.ck(0x100,0)
    c.finish();cases.append(c)
    for md in range(4):
        c=Case(f'mode_{md}');wire=fixture(c,md,17);c.publish(md);complete(c,md,17,wire);c.finish();cases.append(c)
    for n in (255,256,260,261,2047):
        for md in (0,1):
            c=Case(f'length_{n}_mode_{md}');wire=fixture(c,md,n);c.publish(md);complete(c,md,n,wire);c.finish();cases.append(c)
    for lead in (499,500,501):
        c=Case(f'commit_{lead}');wire=fixture(c,0,17);c.publish(0,lead)
        if lead==499:c.event(3);c.ck(0x20100,5<<3,0x38)
        else:complete(c,0,17,wire)
        c.finish();cases.append(c)
    for name,crc,dup in [('crc_error',False,False),('duplicate',True,True)]:
        c=Case(name);wire=fixture(c,1,17,crc=crc,duplicate=dup);c.publish(1);complete(c,1,17,wire,crc=crc,duplicate=dup);c.finish();cases.append(c)
    for alg in (1,2):
        for n in (17,260,2043):
            for md in (0,1):
                c=Case(f'secure_{alg}_{n}_mode_{md}');wire=fixture(c,md,n,alg);c.publish(md);complete(c,md,n,wire,alg);c.finish();cases.append(c)
        c=Case(f'mic_failure_{alg}');wire=fixture(c,1,17,alg,tamper=True);c.publish(1);complete(c,1,17,wire,alg,tamper=True);c.finish();cases.append(c)
    for md in (0,1):
        c=Case(f'cancel_{md}');fixture(c,md,17);c.publish(md);c.event(1);c.w(0x110,0x101)
        if md==0:c.event(6)
        c.event(4);c.finish();cases.append(c)
    c=Case('descriptor_chain_3');fixture(c,0,17);chain(c,3);c.publish();c.event(1)
    for _ in range(3):c.event(6)
    c.event(2);c.check.append((0x40068,3,MASK));c.finish();cases.append(c)
    c=Case('fifo_overflow_soft_reset_recovery');fixture(c,0,17);chain(c,70);c.publish()
    c.poll(0x60,4,4);c.ck(0x24,64,255);c.w(0,3);c.poll(0,0,0x100);c.ck(0x24,0);c.ck(0x60,0)
    for e in range(16):c.ck(0x20100+e*16,0,0x38)
    restore=Case('restore');fixture(restore,0,17)
    for a,v,b in restore.setup:
        if a<0x40000:c.w(a,v,b)
    c.publish();c.event(1);c.event(6);c.event(2);c.finish();cases.append(c)
    c=Case('competition_16');fixture(c,0,17)
    for e in range(1,16):
        for off,v in [(0,9),(0x18,20),(0x20,0x1800),(0x24,0x1c00),(0x58,76)]:c.wr(0x800+e*128+off,v)
        c.mw(0x108+e*16,0x200)
    c.op(7,0x20100,20,0)
    for e in range(16):c.op(9,0x20100+e*16,0,e<<11)
    c.op(3,0,150000,0)
    for e in range(16):c.ck(0x20100+e*16,(4 if e==15 else 5)<<3,0x38)
    c.ck(0x24,18,255);c.check.append((0x40068,1,MASK))
    c.check.append((0xffffff00,0xffff,15));c.finish();cases.append(c)
    for name,mutations,n in [('null_cs',[(0x20108,0)],17),('no_buffer',[(0x22814,0)],17),
       ('capacity_260',[(0x23004,(260<<16)|261)],261),('illegal_2048',[(0x23004,(2047<<16)|2048)],17)]:
        md=1 if name=='no_buffer' else 0
        c=Case(name);fixture(c,md,n)
        for a,v in mutations:c.w(a,v)
        c.publish(md);c.event(5);c.finish();cases.append(c)
    return cases
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    cases=scenarios();stream=[];tcl=['# Generated from cases.py; test keys are public vectors.','set sle_cases {}']
    for ix,c in enumerate(cases,1):
        assert len(c.code)<=1024,c.name
        setup=[(0x4000c,ix,15),*c.setup]
        code=[w for insn in c.code for w in insn]
        tcl.append('lappend sle_cases [list '+c.name+' {'+' '.join(f'{{{a} {v} {b}}}' for a,v,b in setup)+'} {'+' '.join(str(v) for v in code)+'} {'+' '.join(f'{{{a} {v} {m}}}' for a,v,m in c.check)+'}]')
        stream += [(1,0x40014,4,15),(3,100,0,0)]
        stream += [(1,a,v,b) for a,v,b in setup if a!=0x40014]
        stream += [(1,0x44000+i*4,v,15) for i,v in enumerate(code)]
        stream += [(1,0x40014,1,15),(4,ix,0,0)]
        stream += [(6,m,v,0) if a==0xffffff00 else (2,a,v,m) for a,v,m in c.check]
        stream += [(5,ix,0,0)]
    stream.append((0,0,0,0))
    (OUT/'suite.tcl').write_text('\n'.join(tcl)+'\n')
    (ROOT/'verification/board_vectors.mem').write_text('\n'.join(f'{w&MASK:08x}' for row in stream for w in row)+'\n')
    (OUT/'coverage.json').write_text(json.dumps({'cases':[c.name for c in cases],'host_commands':len(stream),'scope':'DIGITAL_TESTER_NO_PHY'},indent=2)+'\n')
    print(len(cases),'board scenarios,',len(stream),'host operations')
if __name__=='__main__':main()
