from pathlib import Path
import re,shutil,hashlib,json,argparse
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('stage',type=Path);p.add_argument('--collect',action='store_true');a=p.parse_args()
out=ROOT/'build/board';out.mkdir(parents=True,exist_ok=True)
if a.collect:
    meta=json.loads((a.stage/'manifest.json').read_text())
    for n,h in meta['sources'].items():
        if n.startswith('board/tools/') and Path(n).name not in {'build.tcl','finish.tcl','ps_preset.tcl','resume_reset_fix.tcl'}:continue
        assert hashlib.sha256((ROOT/n).read_bytes()).hexdigest()==h,('Changed source',n)
        if Path(n).suffix in ('.v','.vh'):
            assert hashlib.sha256((a.stage/'rtl'/Path(n).name).read_bytes()).hexdigest()==h,('Staged source changed',n)
    shutil.copytree(a.stage/'results',out,dirs_exist_ok=True)
    shutil.copy2(a.stage/'build.log',out/'build.log')
    if (a.stage/'debug_clocks.log').exists():
        shutil.copy2(a.stage/'debug_clocks.log',out/'debug_clocks.log')
    logs=out/'implementation_logs'
    logs.mkdir(exist_ok=True)
    for log in (a.stage/'project/sle_board.runs').glob('*/runme.log'):
        dest=logs/log.parent.name;dest.mkdir(exist_ok=True)
        shutil.copy2(log,dest/'runme.log')
    for n in ('sle_board.bit','sle_board.ltx','ps7_init.tcl'):
        assert (out/n).exists(),n
    fixed={'sle_board.bit','sle_board.ltx','sle_board.xsa','ps7_init.tcl','implementation.json','timing.rpt','utilization.rpt','drc.rpt','cdc.rpt','check_timing.rpt','methodology.rpt','bus_skew.rpt','build.log','debug_clocks.rpt','debug_clocks.log'}
    meta['artifacts']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file() and p.name in fixed}
    meta['artifacts'].update({p.relative_to(out).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in logs.rglob('runme.log')})
    meta['sources']={n:h for n,h in meta['sources'].items() if not n.startswith('board/tools/') or Path(n).name in {'build.tcl','finish.tcl','ps_preset.tcl','resume_reset_fix.tcl'}}
    meta['runtime_sources']={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'board').rglob('*') if p.is_file() and p.suffix in ('.tcl','.py','.ps1','.json')}
    meta['tool']={'name':'Vivado','version':'2020.2','build':'3064766','part':'xc7z100ffg900-2'}
    meta['ip_vlnv']=sorted(set(re.findall(r'-vlnv\s+([^\s]+)',(a.stage/'tools/build.tcl').read_text())))
    meta['reference_inputs']=json.loads((ROOT/'docs/source_manifest.json').read_text(encoding='utf-8'))
    meta['generated_configuration_hashes']={p.relative_to(a.stage).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
      for p in (a.stage/'project').rglob('*') if p.is_file() and p.suffix in ('.xci','.xdc','.bd') and '.Xil' not in p.parts}
    (out/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n');print(out);raise SystemExit
(a.stage/'rtl').mkdir(parents=True,exist_ok=True);(a.stage/'tools').mkdir(exist_ok=True)
sources={}
for f in ROOT.rglob('*'):
    if f.is_file() and f.suffix in ('.v','.vh') and not {'build','external','verification'}&set(f.relative_to(ROOT).parts):
        shutil.copy2(f,a.stage/'rtl'/f.name);sources[f.relative_to(ROOT).as_posix()]=hashlib.sha256(f.read_bytes()).hexdigest()
for f in (ROOT/'board/tools').glob('*.tcl'):
    shutil.copy2(f,a.stage/'tools'/f.name);sources[f.relative_to(ROOT).as_posix()]=hashlib.sha256(f.read_bytes()).hexdigest()
(a.stage/'manifest.json').write_text(json.dumps({'sources':sources,'scope':'DIGITAL_TESTER_NO_PHY','stage':str(a.stage)},indent=2)+'\n')
print(a.stage)
