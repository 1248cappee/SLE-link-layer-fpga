"""Record actual generated IP references and host oracle-library versions."""
from pathlib import Path
import json,hashlib,sys,xml.etree.ElementTree as ET,importlib.metadata
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'build/board'
meta=json.loads((OUT/'manifest.json').read_text());stage=Path(meta['stage'])
refs=[]
for relative,expected in meta['generated_configuration_hashes'].items():
 if not relative.endswith('.xci'):continue
 path=stage/relative
 assert hashlib.sha256(path.read_bytes()).hexdigest()==expected,('IP configuration changed',relative)
 tree=ET.parse(path)
 for ref in tree.findall('.//{*}componentRef'):
  fields={k.rsplit('}',1)[-1]:v for k,v in ref.attrib.items()}
  refs.append(dict(configuration=relative,sha256=expected,vlnv=':'.join(fields[k] for k in ('vendor','library','name','version'))))
libraries={}
for name in ('cryptography','pycryptodome','gmssl'):
 try:libraries[name]=importlib.metadata.version(name)
 except importlib.metadata.PackageNotFoundError:libraries[name]=None
xsct=(OUT/'xsct_version.txt').read_text(encoding='utf-8-sig') if (OUT/'xsct_version.txt').exists() else None
assert xsct is None or 'SLE_XSCT_VERSION xsct 2020.2' in xsct,'XSCT version readback failed'
result=dict(vivado=meta['tool'],xsct=xsct,python=sys.version,oracle_libraries=libraries,
            bit_sha256=meta['artifacts']['sle_board.bit'],generated_ip=refs,
            debug_hub='xilinx.com:ip:xsdbm:3.0 (also recorded in implementation log)')
(OUT/'tool_ip_versions.json').write_text(json.dumps(result,indent=2)+'\n')
print('SLE_TOOL_IP_VERSIONS_RECORDED',len(refs),'configurations',sorted({r['vlnv'] for r in refs}))
