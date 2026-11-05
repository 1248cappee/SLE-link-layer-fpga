from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
header=(ROOT/'rw_ble_top/verilog/rtl/rw_ble_top.v').read_text(encoding='ascii').split(');',1)[0]
lines=[]
for d,w,n in re.findall(r'\b(input|output)\s+wire\s*(\[[^]]+\])?\s*(\w+)',header):
    if n=='clk':lines.append('reg clk=0;always #25 clk=~clk;')
    elif d=='input':lines.append(f'reg {w} {n}=0;')
    else:lines.append(f'wire {w} {n};')
(ROOT/'verification/system_ports.vh').write_text('\n'.join(lines)+'\n',encoding='ascii')
