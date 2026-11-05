from pathlib import Path
import os,shutil,subprocess,sys,json,argparse,hashlib
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--stage-root',type=Path)
parser.add_argument('--top',default='rw_ble_top')
parser.add_argument('--prepare-only',action='store_true')
parser.add_argument('--collect',action='store_true')
args=parser.parse_args()
build=ROOT/'build';build.mkdir(exist_ok=True)
stage=(args.stage_root or build)/'ooc_stage';stage.mkdir(parents=True,exist_ok=True)
if args.collect:
    metadata=json.loads((stage/'run_config.json').read_text(encoding='utf-8'))
    constraints=hashlib.sha256((stage/'ooc.tcl').read_bytes()).hexdigest()
    assert constraints==hashlib.sha256((ROOT/'tools/ooc.tcl').read_bytes()).hexdigest(),'Constraints changed'
    metadata['constraints_sha256']=constraints
    for name,h in metadata['source_hashes'].items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==h,('Source changed',name)
        assert hashlib.sha256((stage/Path(name).name).read_bytes()).hexdigest()==h,('Staged source changed',name)
    result=json.loads((stage/'result.json').read_text())
    assert result['setup_slack_ns']>=0 and result['hold_slack_ns']>=0
    for name in ['result.json','utilization_synth.rpt','utilization_routed.rpt','timing_routed.rpt','drc_routed.rpt','synthesized.dcp','routed.dcp']:
        shutil.copy2(stage/name,build/name)
    result.update(metadata)
    (build/'result.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    if (stage/'final_direct.log').exists():shutil.copy2(stage/'final_direct.log',build/'ooc.log')
    print('SLE_OOC_PASS',result['setup_slack_ns'],result['hold_slack_ns'])
    raise SystemExit(0)
source_hashes={}
for p in list(ROOT.rglob('*.v'))+list(ROOT.rglob('*.vh')):
    if not {'build','external','verification'} & set(p.relative_to(ROOT).parts):
        shutil.copy2(p,stage/p.name)
        source_hashes[str(p.relative_to(ROOT)).replace('\\','/')]=hashlib.sha256(p.read_bytes()).hexdigest()
shutil.copy2(ROOT/'tools/ooc.tcl',stage/'ooc.tcl')
(stage/'run_config.json').write_text(json.dumps(dict(top=args.top,source_hashes=source_hashes,stage=str(stage)),indent=2)+'\n',encoding='utf-8')
if args.prepare_only:
    print(stage);raise SystemExit(0)
# Warm the local Tcl runtime files before Vivado starts on this installation.
for runtime in Path(r'D:\vivado\Vivado\2020.2\scripts\rt').rglob('*.tcl'):
    runtime.read_bytes()
env=dict(os.environ,PROCESSOR_ARCHITECTURE='AMD64',LANG='C',LC_ALL='C',LC_CTYPE='C',SLE_SYNTH_TOP=args.top)
with (build/'ooc.log').open('w',encoding='utf-8') as log:
    r=subprocess.run(['cmd.exe','/d','/c',r'D:\vivado\Vivado\2020.2\bin\vivado.bat','-mode','batch','-source','ooc.tcl','-notrace'],cwd=stage,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=7200)
if r.returncode or not (stage/'result.json').exists():
    print((build/'ooc.log').read_text(encoding='utf-8',errors='replace')[-7000:]);sys.exit(1)
for name in ['result.json','utilization_synth.rpt','utilization_routed.rpt','timing_routed.rpt','drc_routed.rpt']:
    shutil.copy2(stage/name,build/name)
metadata=json.loads((build/'result.json').read_text())
metadata.update(top=args.top,source_hashes=source_hashes,stage=str(stage))
(build/'result.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
print((stage/'result.json').read_text());print('SLE_OOC_PASS')
