"""Package the verified PHY-free RTL, tests, bitstream and board evidence."""
from pathlib import Path
import zipfile,runpy,json,hashlib,sys,argparse
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--skip-pressure',action='store_true',help='Package functional board acceptance with pressure explicitly excluded')
args=parser.parse_args()
sys.path.insert(0,str(ROOT/'board/tools'))
runpy.run_path(str(ROOT/'board/tools/verify.py'))
assert runpy.run_path(str(ROOT/'board/tools/cm_report.py'))['main'](skip_pressure=args.skip_pressure)==0,'CM board acceptance incomplete'
runpy.run_path(str(ROOT/'tools/audit_cm.py'),run_name='__main__')
files=set()
for part in ('CM','common','board','verification'):
    files.update(p for p in (ROOT/part).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
for part in ROOT.glob('rw_ble_*'):
    if part.is_dir():files.update(p for p in part.rglob('*') if p.is_file())
files.update(p for p in (ROOT/'tools').iterdir() if p.is_file())
files.update(ROOT/n for n in ('README.md','rtl.f','board.f'))
for n in ('BOARD_ACCEPTANCE.md','ACCEPTANCE.md','INTERFACE.md','PARAMETERS.md','module_allocation.json','module_mapping.json','source_manifest.json','cm_mapping.json','CM_INTERFACE.md','CM_ACCEPTANCE.md','CM_IMPLEMENTATION_STATUS.md','CM_BOARD_ISSUES.md','cm_requirements_coverage.json'):
    files.add(ROOT/'docs'/n)
files.add(ROOT/'docs/CM_TOOL_WARNINGS.md')
files.update(ROOT/'docs'/n for n in ('PHY_ISSUES.md','phy_source_lock.json','resource_contract.json','requirements_coverage.json'))
files.update(p for p in (ROOT/'build/board').rglob('*') if p.is_file() and p.suffix not in ('.jou',))
files.add(ROOT/'build/test_results.json');files.add(ROOT/'build/reset_ip_sim.log')
files.add(ROOT/'build/regeneration_audit.json')
files.update(ROOT/'build'/n for n in ('cm_crypto_bram.json','cm_crypto_bram.rpt','cm_crypto_bram.log','cm_crypto_bram_drc.rpt'))
tests=json.loads((ROOT/'build/test_results.json').read_text())
files.update(ROOT/'build'/(t['test']+'.log') for t in tests['results'])
archive=ROOT/('build/SLE_CM_P101_NO_PHY_FUNCTIONAL.zip' if args.skip_pressure else 'build/SLE_CM_P101_NO_PHY_VERIFIED.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in sorted(files):z.write(p,'SLE/'+p.relative_to(ROOT).as_posix())
    hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}
    z.writestr('DELIVERY_SHA256.json',json.dumps(hashes,indent=2)+'\n')
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print('FUNCTIONAL_BOARD_DELIVERY' if args.skip_pressure else 'VERIFIED_BOARD_DELIVERY',archive,archive.stat().st_size,'bytes',len(files),'files')
