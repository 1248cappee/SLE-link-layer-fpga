"""Record updated host scripts only after hardware sources/artifacts match."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
out=ROOT/'build/board';path=out/'manifest.json';meta=json.loads(path.read_text())
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for n,h in meta['sources'].items():assert digest(ROOT/n)==h,('Hardware source changed',n)
for n,h in meta['artifacts'].items():assert digest(out/n)==h,('Hardware artifact changed',n)
meta['runtime_sources']={p.relative_to(ROOT).as_posix():digest(p) for p in (ROOT/'board').rglob('*') if p.is_file() and p.suffix in ('.tcl','.py','.ps1','.json')}
path.write_text(json.dumps(meta,indent=2)+'\n')
print('Runtime scripts sealed; hardware unchanged')
