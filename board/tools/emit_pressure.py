"""Emit the real duration-bounded hardware pressure program."""
from cases import Case,fixture,complete,words,pattern
from cm_cases import pressure,ROOT
c=pressure(Case,fixture,complete,words,pattern)
assert len(c.code)<=1024
code=[w for instruction in c.code for w in instruction]
text='set sle_cases {}\nlappend sle_cases [list '+c.name+' {'+' '.join(f'{{{a} {v} {b}}}' for a,v,b in c.setup)+'} {'+' '.join(str(v) for v in code)+'} {'+' '.join(f'{{{a} {v} {m}}}' for a,v,m in c.check)+'}]\n'
(ROOT/'board/cases/pressure.tcl').write_text(text,encoding='ascii')
print('Pressure program',len(c.code),'instructions; minimum 36000000000 cycles')
