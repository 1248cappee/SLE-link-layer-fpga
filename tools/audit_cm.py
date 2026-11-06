"""Current CM provenance and directed requirement coverage; no legacy OOC reuse."""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[1]
def read(n):return json.loads((ROOT/n).read_text(encoding='utf-8'))
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
inputs=read('docs/source_manifest.json')
assert all(digest(ROOT.parent/n)==v['sha256'] for n,v in inputs.items()),'Reference input changed'
phy=read('docs/phy_source_lock.json')
assert all(digest(ROOT/r['relative'])==r['sha256'] for r in phy['files']),'Frozen PHY changed'
ble=read('docs/module_mapping.json');cm=read('docs/cm_mapping.json')
assert len(ble)==43 and len(cm)==95
assert all(x['status']!='PENDING' for x in cm)
compiled=set((ROOT/'rtl.f').read_text().splitlines())
for row in cm:
 if row['status']=='EXCLUDED_BY_PROFILE':
  assert row['target'] is None and row['source'] not in compiled,row['source']
 else:
  target=ROOT/row['target']
  assert row['target'] in compiled,('Mapped CM function missing from filelist',row['module'])
  assert digest(target)!=row['source_sha256'],('Reference CM RTL copied directly',row['module'])
  if row['status']=='IMPLEMENTED':
   assert re.search(r'\bmodule\s+'+re.escape(row['module'])+r'\b',target.read_text()),row['module']
for row in ble:
 assert re.search(r'\bmodule\s+'+re.escape(row['module'])+r'\b',(ROOT/row['target']).read_text()),row['target']
tests=read('build/test_results.json')
current_sources={p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*')
 if p.is_file() and p.suffix in ('.v','.vh','.sv','.mem') and not {'build','external'}&set(p.relative_to(ROOT).parts)}
assert current_sources==set(tests['source_hashes']),'Tested source set differs from current source set'
required=set(re.findall(r'\btb_\w+',(ROOT/'tools/sim.ps1').read_text()))
assert {r['test'] for r in tests['results'] if r['passed']}==required
assert all(digest(ROOT/n)==h for n,h in tests['source_hashes'].items()),'Simulation sources stale'
for name in required:
 log=(ROOT/'build'/f'{name}.log').read_text(errors='replace')
 assert f'SLE_TEST_PASS: {name}' in log and 'Fatal:' not in log and 'ERROR:' not in log,name
crypto=ROOT/'CM/rw_cm_crypto_engine/verilog/rtl'
for parent,children in {
 'rw_cm_aes_top':['rw_cm_aes_fsm','rw_cm_aes_cipher_decipher'],
 'rw_cm_aes_cipher_decipher':['rw_cm_aes_keyexpansion','rw_cm_aes_sbox','rw_cm_aes_shiftrows','rw_cm_aes_mixcolumns'],
 'rw_cm_aes_keyexpansion':['rw_cm_aes_sbox'],
 'sle_cm_sm4_cipher':['sle_cm_sm4_keyexpansion','sle_cm_sm4_round']}.items():
 text=re.sub(r'//[^\n]*','',(crypto/(parent+'.v')).read_text())
 for child in children:
  assert re.search(r'\b'+child+r'\s+(?:#\s*\(|\w+\s*\()',text),('CM child not instantiated',parent,child)
assert all(row['target']!='common/rtl/sle_block_cipher.v' for row in cm),'Monolithic AES fallback remains'
bram=read('build/cm_crypto_bram.json')
assert bram['passed'] and bram['block_ram_cells']>=1,'CCM private RAM not proven in BRAM'
assert all(digest(ROOT/n)==h for n,h in bram['source_hashes'].items()),'Stale CCM BRAM proof'
assert all(digest(ROOT/'build'/n)==h for n,h in bram['artifacts'].items()),'CCM BRAM evidence changed'
coverage=[]
for ident,implementation,unit,board in [
 ('CM-GRID','sle_schedule_grid and activity scheduler',['tb_cm','tb_cm_system'],['cm_grid_*','cm_mixed_grid_competition_16']),
 ('CM-SLEEP','AON FSM, gated main domain and phase/day resync',['tb_cm_sleep','tb_cm_day'],['cm_sleep_*']),
 ('CM-CDC','single-bit synchronizers, toggle ACK and bundled-data handshake',['tb_cm_cdc'],['cm_sleep_*']),
 ('CM-BUS','separate REG/EM AHB/XBAR state machines',['tb_bus','tb_board_axi','tb_em_reset'],['foundation_full_em','cm_sleep_*']),
 ('CM-DIAG','all-client EM counters and first-fault capture',['tb_cm_system'],['cm_software_ccm_*']),
 ('CM-SECURITY','CM AES round/key/transform hierarchy, separate SM4, payload and single-frame slot/day CCM; maximum 39-bit counter rejects the next packet and recovers after reconfiguration',['tb_cm_cipher','tb_crypto','tb_cm_system','tb_cm_day','tb_secure_chain'],['secure_*','mic_failure_*','cm_slot_nonce_*']),
 ('CM-IRQ','CM sticky W1C interrupt bank and aggregation without changing original IRQ meanings',['tb_cm_system','tb_registers'],['register_time_irq','cm_software_ccm_*']),
 ('CM-RADIO','Native configuration/data/result/stop/drain and pending-read ownership; separate RAM/CRC/MIC/delivery outcomes',['tb_control','tb_system','tb_recovery'],['mic_failure_*','cm_error_recovery_*']),
 ('CM-SW-CCM','exclusive software DMA and final-result ACK ordering',['tb_cm_system'],['cm_software_ccm_*']),
 ('CM-COEX','grant, priority, denial and packet-boundary withdrawal',['tb_board_suite'],['cm_coex_*']),
 ('CM-LONG-RUN','per-cycle data/event checks, retained EM and clock-stop checks',['tb_board_suite'],['cm_sleep_10000','cm_pressure_short','cm_pressure_30min'])]:
 coverage.append(dict(id=ident,implementation=implementation,unit_tests=unit,board_cases=board,
  status='SIMULATED_DIRECTED; hardware acceptance in cm_acceptance.json'))
contract=read('docs/resource_contract.json')
result={'scope':'DIRECTED_SLE_CM_NO_PHY','references_unchanged':True,'frozen_phy_files':len(phy['files']),
 'ble_correspondences':43,'cm_correspondences':95,'cm_excluded':sum(r['status']=='EXCLUDED_BY_PROFILE' for r in cm),
 'simulation_tests':len(required),'new_requirements':coverage,
 'resource_contract_rows':{book:{sheet:[row['row'] for row in rows] for sheet,rows in sheets.items() if isinstance(rows,list)} for book,sheets in contract.items()},
 'limits':['No full SLE certification','No HMAC-SM3 or key negotiation','Slot/day profile: one frame per TX/RX activity',
           'Virtual low-rate reference; no independent oscillator/power measurement','No real PHY/RF acceptance']}
(ROOT/'docs/cm_requirements_coverage.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('SLE_CM_SOURCE_AND_SIM_AUDIT_PASS',len(required),'tests,43+95 mappings,',len(phy['files']),'frozen PHY files')
