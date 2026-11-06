"""Check evidence freshness and report simulation/implementation/board separately."""
from pathlib import Path
import json,hashlib,csv,re
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'build/board';OUT.mkdir(parents=True,exist_ok=True)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def check_time_csv(path):
    samples=[]
    with path.open(newline='') as fp:
        reader=csv.reader(fp);header=next(reader)
        candidates=[i for i,n in enumerate(header) if 'trace' in n.lower() or 'probe0' in n.lower()]
        assert len(candidates)==1,('Trace CSV column',header)
        col=candidates[0]
        for row in reader:
            if len(row)<=col:continue
            value=row[col].strip().replace('_','')
            if not re.fullmatch('[0-9a-fA-F]+',value):continue
            v=int(value,16);samples.append(((v>>173)&0x3fffffff,(v>>163)&1023))
    assert len(samples)>=100,('Not enough ILA samples',len(samples))
    edges=[]
    for i,((s,f),(ns,nf)) in enumerate(zip(samples,samples[1:]),1):
        if (s,f)==(ns,nf):continue
        assert (ns,nf)==(((s+1)&0x3fffffff,0) if f==249 else (s,f+1)),('Time step',i,s,f,ns,nf)
        edges.append(i)
    assert len(edges)>10
    assert all(b-a==10 for a,b in zip(edges,edges[1:])),('Fine divider',edges[:30])
    return {'samples':len(samples),'fine_edges':len(edges),'clocks_per_fine':10}
def main():
    tests=json.loads((ROOT/'build/test_results.json').read_text())
    fresh=all((ROOT/n).exists() and digest(ROOT/n)==h for n,h in tests['source_hashes'].items())
    current={p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*') if p.is_file() and p.suffix in ('.v','.vh','.sv','.mem') and not {'build','external'}&set(p.relative_to(ROOT).parts)}
    fresh=fresh and current==set(tests['source_hashes'])
    required=set(re.findall(r'\btb_\w+', (ROOT/'tools/sim.ps1').read_text()))
    simulation=fresh and {t['test'] for t in tests['results']}==required and all(t['passed'] for t in tests['results'])
    implementation=(OUT/'implementation.json').exists() and (OUT/'manifest.json').exists()
    if implementation:
        meta=json.loads((OUT/'manifest.json').read_text())
        implementation=all(digest(ROOT/n)==h for n,h in meta['sources'].items()) and all(digest(OUT/n)==h for n,h in meta['artifacts'].items())
    boards=json.loads((OUT/'board_results.json').read_text()) if (OUT/'board_results.json').exists() else {'cases':[]}
    scenarios=json.loads((ROOT/'board/cases/coverage.json').read_text())['cases']
    passed={c['name'] for c in boards['cases'] if c['passed']}
    expected=set(scenarios)
    image_matches=(OUT/'sle_board.bit').exists() and boards.get('bit_sha256')==digest(OUT/'sle_board.bit')
    time_evidence=None;time_error=None
    if 'foundation_full_em' in passed:
        try:time_evidence=check_time_csv(OUT/'ila_foundation_full_em.csv')
        except Exception as e:time_error=str(e)
    captures=all((OUT/f'ila_{name}.csv').exists() for name in expected)
    base={'foundation_full_em','register_time_irq','fifo_overflow_soft_reset_recovery'}
    reset_log=ROOT/'build/reset_ip_sim.log'
    reset_ip=reset_log.exists() and 'SLE_BOARD_RESET_IP_PASS' in reset_log.read_text(errors='replace')
    result={'scope':'DIGITAL_TESTER_NO_PHY','simulation_passed':simulation,'simulation_tests':len(tests['results']),'board_reset_ip_passed':reset_ip,
      'implementation_present':implementation,'board_image_matches':image_matches,'base_board_passed':base<=passed and bool(time_evidence) and image_matches and implementation,
      'closed_loop_board_passed':passed==expected and captures and bool(time_evidence) and image_matches and implementation,
      'board_passed_count':len(passed),'board_expected_count':len(expected),'missing_or_failed':sorted(expected-passed),
      'time_ila':time_evidence,'time_ila_error':time_error,'real_phy_tested':False,'rf_tested':False}
    (OUT/'acceptance.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps(result,ensure_ascii=False,indent=2))
    return 0 if result['base_board_passed'] and result['closed_loop_board_passed'] and simulation and implementation else 1
if __name__=='__main__':raise SystemExit(main())
