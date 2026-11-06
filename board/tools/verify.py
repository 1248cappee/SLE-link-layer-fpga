from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[2]
out=ROOT/'build/board';meta=json.loads((out/'manifest.json').read_text())
rtl_now={p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*') if p.is_file() and p.suffix in ('.v','.vh') and not {'build','external','verification'}&set(p.relative_to(ROOT).parts)}
assert rtl_now=={n for n in meta['sources'] if Path(n).suffix in ('.v','.vh')},'Hardware source set changed'
for n,h in meta['sources'].items():
    assert hashlib.sha256((ROOT/n).read_bytes()).hexdigest()==h,('Source changed',n)
for n,h in meta['artifacts'].items():
    assert hashlib.sha256((out/n).read_bytes()).hexdigest()==h,('Artifact changed',n)
for n,h in meta.get('runtime_sources',{}).items():
    assert hashlib.sha256((ROOT/n).read_bytes()).hexdigest()==h,('Runtime script changed',n)
methodology=(out/'methodology.rpt').read_text(errors='replace')
assert not re.search(r'LUT cell board_i/test_core/[^\n]*drives asynchronous',methodology),'Own RTL has a combination-driven asynchronous reset'
assert 'debug_clocks.rpt' in meta['artifacts'],'Physical debug clock check is not sealed'
assert 'SLE_DEBUG_CLOCK_CHECK_PASS' in (out/'debug_clocks.rpt').read_text(),'Debug clocks not verified in AON domain'
print('SLE_BOARD_ARTIFACT_HASHES_PASS')
