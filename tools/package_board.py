"""Package the verified PHY-free RTL, tests, bitstream and board evidence."""
from pathlib import Path
import zipfile,runpy,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
runpy.run_path(str(ROOT/'board/tools/verify.py'))
assert runpy.run_path(str(ROOT/'board/tools/report.py'))['main']()==0,'Board acceptance incomplete'
files=set()
for part in ('common','board','verification'):
    files.update(p for p in (ROOT/part).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
for part in ROOT.glob('rw_ble_*'):
    if part.is_dir():files.update(p for p in part.rglob('*') if p.is_file())
files.update(p for p in (ROOT/'tools').iterdir() if p.is_file())
files.update(ROOT/n for n in ('README.md','rtl.f','board.f'))
for n in ('BOARD_ACCEPTANCE.md','ACCEPTANCE.md','INTERFACE.md','PARAMETERS.md','module_allocation.json','module_mapping.json','source_manifest.json'):
    files.add(ROOT/'docs'/n)
files.update(p for p in (ROOT/'build/board').iterdir() if p.is_file() and p.suffix not in ('.jou',))
files.add(ROOT/'build/test_results.json');files.add(ROOT/'build/reset_ip_sim.log')
tests=json.loads((ROOT/'build/test_results.json').read_text())
files.update(ROOT/'build'/(t['test']+'.log') for t in tests['results'])
archive=ROOT/'build/SLE_P101_NO_PHY_VERIFIED.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in sorted(files):z.write(p,'SLE/'+p.relative_to(ROOT).as_posix())
    hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)}
    z.writestr('DELIVERY_SHA256.json',json.dumps(hashes,indent=2)+'\n')
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print('VERIFIED_BOARD_DELIVERY',archive,archive.stat().st_size,'bytes',len(files),'files')
