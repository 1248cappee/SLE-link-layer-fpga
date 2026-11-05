"""Fetch only immutable PHY sources/vectors, verify Git blob hashes, never edit them."""
from pathlib import Path
import subprocess,json,hashlib,base64,concurrent.futures
ROOT=Path(__file__).resolve().parents[1]
REPO='1248cappee/SLE_MAC_PHY_RX_INTEGRATION'
COMMIT='c4d848fd9c35554043b6fd01eb4c63b848931da0'
PREFIX='hw/board/p101_phy_rf/'
DEST=ROOT/'external/p101_phy_rf'
def api(path):
    p=subprocess.run(['gh','api','--method','GET','repos/'+REPO+'/'+path],stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True)
    return json.loads(p.stdout)
def git_hash(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
tree=api('git/trees/'+COMMIT+'?recursive=1')['tree']
allowed={'.v','.sv','.vh','.list','.mem','.len','.cfg','.csv','.md','.tcl','.info','.ctrl','.ctrlcoded'}
items=[x for x in tree if x['type']=='blob' and x['path'].startswith(PREFIX) and
       (x['path'].startswith(PREFIX+'phy/') or x['path'].startswith(PREFIX+'sim/') or x['path'].startswith(PREFIX+'rtl/')) and
       Path(x['path']).suffix in allowed]
print('Fetching',len(items),'PHY files,',sum(x.get('size',0) for x in items),'bytes.',flush=True)
def fetch(item):
    target=DEST/item['path'].removeprefix(PREFIX)
    if not target.exists() or git_hash(target.read_bytes())!=item['sha']:
        data=base64.b64decode(api('git/blobs/'+item['sha'])['content'])
        assert git_hash(data)==item['sha'],item['path']
        target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    return {'path':item['path'],'relative':str(target.relative_to(ROOT)).replace('\\','/'),'git_blob':item['sha'],'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    manifest=[]
    for i,entry in enumerate(pool.map(fetch,items),1):
        manifest.append(entry)
        if i%10==0:print('Verified',i,'/',len(items),flush=True)
(ROOT/'docs/phy_source_lock.json').write_text(json.dumps({'repository':REPO,'commit':COMMIT,'files':manifest},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PHY source snapshot verified; no source patches applied.',flush=True)
