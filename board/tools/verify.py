from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[2]
out=ROOT/'build/board';meta=json.loads((out/'manifest.json').read_text())
for n,h in meta['sources'].items():
    assert hashlib.sha256((ROOT/n).read_bytes()).hexdigest()==h,('Source changed',n)
for n,h in meta['artifacts'].items():
    assert hashlib.sha256((out/n).read_bytes()).hexdigest()==h,('Artifact changed',n)
for n,h in meta.get('runtime_sources',{}).items():
    assert hashlib.sha256((ROOT/n).read_bytes()).hexdigest()==h,('Runtime script changed',n)
print('SLE_BOARD_ARTIFACT_HASHES_PASS')
