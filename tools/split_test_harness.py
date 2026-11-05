from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=root/'verification/tb_system.sv'
s=p.read_text(encoding='ascii')
marker=' initial begin\n  phy_caps=15;hready_in=1;'
prefix,tail=s.split(marker,1)
harness=prefix.split('module tb_system;\n',1)[1]
(p.parent/'system_harness.vh').write_text(harness,encoding='ascii')
p.write_text('`timescale 1ns/1ps\nmodule tb_system;\n `include "system_harness.vh"\n'+marker+tail,encoding='ascii')
