"""Regenerate in an isolated copy; never touch the accepted hardware sources."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,uuid,contextlib
ROOT=Path(__file__).resolve().parents[1]
def tracked(root):
 return {p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
   for p in root.rglob('*') if p.is_file() and (p.suffix in ('.v','.vh','.sv','.mem') or p.name in ('rtl.f','board.f'))
   and not {'build','external','__pycache__'}&set(p.relative_to(root).parts)}
before=tracked(ROOT);commands=[]
with contextlib.nullcontext(ROOT/'build'/('regen_'+uuid.uuid4().hex[:8])) as parent:
 parent.mkdir();clone=parent/'SLE';clone.mkdir()
 for source in ROOT.iterdir():
  if source.is_dir() and (source.name in ('CM','common','board','docs','tools','verification') or source.name.startswith('rw_ble_')):
   shutil.copytree(source,clone/source.name,ignore=shutil.ignore_patterns('__pycache__','build','external','.git'))
  elif source.name in ('rtl.f','board.f'):shutil.copy2(source,clone/source.name)
 for name in ('BLE.zip','CM.zip'):shutil.copy2(ROOT.parent/name,parent/name)
 for name in ('tools/generate_boundaries.py','tools/integrate.py','tools/gen_tb_ports.py','board/generate.py','tools/package.py','tools/cm_inventory.py'):
  result=subprocess.run([sys.executable,'-X','utf8',str(clone/name)],cwd=clone,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
  commands.append(dict(script=name,exit_code=result.returncode,output=result.stdout+result.stderr))
  assert result.returncode==0,commands[-1]
 after=tracked(clone)
 changed=sorted(n for n in before.keys()|after.keys() if before.get(n)!=after.get(n))
 result=dict(passed=not changed,tracked_files=len(before),changed_files=changed,commands=commands)
 (ROOT/'build/regeneration_audit.json').write_text(json.dumps(result,indent=2)+'\n')
 assert not changed,('Regeneration would overwrite accepted sources',changed)
print('SLE_REGENERATION_AUDIT_PASS',len(before),'RTL/test/filelist objects unchanged')
