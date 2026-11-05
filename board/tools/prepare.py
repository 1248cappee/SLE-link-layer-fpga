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
    for n in ('sle_board.bit','sle_board.ltx','ps7_init.tcl'):
        assert (out/n).exists(),n
    fixed={'sle_board.bit','sle_board.ltx','sle_board.xsa','ps7_init.tcl','implementation.json','timing.rpt','utilization.rpt','drc.rpt','cdc.rpt','check_timing.rpt','methodology.rpt','bus_skew.rpt'}
    meta['artifacts']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file() and p.name in fixed}
    meta['sources']={n:h for n,h in meta['sources'].items() if not n.startswith('board/tools/') or Path(n).name in {'build.tcl','finish.tcl','ps_preset.tcl','resume_reset_fix.tcl'}}
    meta['runtime_sources']={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'board').rglob('*') if p.is_file() and p.suffix in ('.tcl','.py','.ps1','.json')}
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
