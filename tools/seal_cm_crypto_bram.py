"""Bind directed CCM BRAM proof to the exact staged core sources."""
from pathlib import Path
import argparse,hashlib,json
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('stage',type=Path);args=parser.parse_args()
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
path=root/'build/cm_crypto_bram.json';result=json.loads(path.read_text())
assert result['passed'] and result['block_ram_cells']>=1
log=(root/'build/cm_crypto_bram.log').read_text(errors='replace')
assert 'SLE_CM_CRYPTO_BRAM_PASS ccm/memory_reg' in log
assert 'Synth 8-6849' not in log and 'ERROR:' not in log
sources=[root/n for n in (root/'rtl.f').read_text().splitlines() if n.endswith('.v')]
sources+=list((root/'common/rtl').glob('*.vh'))
hashes={}
for source in sources:
    expected=digest(source)
    assert digest(args.stage/'rtl'/source.name)==expected,('Stale CCM synthesis source',source)
    hashes[source.relative_to(root).as_posix()]=expected
result.update(source_hashes=hashes,stage=str(args.stage),tool='Vivado 2020.2',
 artifacts={n:digest(root/'build'/n) for n in ('cm_crypto_bram.rpt','cm_crypto_bram.log','cm_crypto_bram_drc.rpt')})
path.write_text(json.dumps(result,indent=2)+'\n')
print('SLE_CM_CRYPTO_BRAM_SOURCES_PASS',len(hashes),'core RTL/header files')
