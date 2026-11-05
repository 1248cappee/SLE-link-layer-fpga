"""Run real XSim compilation/elaboration/simulation in an ASCII staging path."""
from pathlib import Path
import argparse, os, shutil, subprocess, uuid, json, time, hashlib
ROOT=Path(__file__).resolve().parents[1]
def run():
    p=argparse.ArgumentParser()
    p.add_argument('tests',nargs='*',default=['tb_primitives'])
    p.add_argument('--vivado',default=r'D:\vivado\Vivado\2020.2')
    p.add_argument('--append',action='store_true',help='Append tests only if every previously tested source is unchanged')
    a=p.parse_args()
    build=ROOT/'build';build.mkdir(exist_ok=True)
    stage=build/('xsim_'+uuid.uuid4().hex[:8]);stage.mkdir()
    for source in list(ROOT.rglob('*.v'))+list(ROOT.rglob('*.vh'))+list((ROOT/'verification').glob('*.sv'))+list((ROOT/'verification').glob('*.mem')):
        if not {'build','external'} & set(source.relative_to(ROOT).parts):shutil.copy2(source,stage/source.name)
    env=dict(os.environ,PROCESSOR_ARCHITECTURE='AMD64')
    source_hashes={str(x.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(x.read_bytes()).hexdigest() for x in ROOT.rglob('*') if x.is_file() and x.suffix in ('.v','.vh','.sv','.mem') and not {'build','external'} & set(x.relative_to(ROOT).parts)}
    results=[]
    if a.append:
        previous=json.loads((build/'test_results.json').read_text(encoding='utf-8'))
        selected={f'verification/{t}.sv' for t in a.tests}
        assert all(source_hashes.get(n)==h or n in selected for n,h in previous['source_hashes'].items()),'Previously tested sources changed; run full suite'
        results=[r for r in previous['results'] if r['test'] not in a.tests]
    def command(name,args,log):
        binary=Path(a.vivado)/'bin'/(name+'.bat')
        r=subprocess.run(['cmd.exe','/d','/c',str(binary),*args],cwd=stage,env=env,text=True,encoding='utf-8',errors='replace',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=900)
        log.write(r.stdout);log.flush()
        if r.returncode:raise RuntimeError(f'{name} exit {r.returncode}:\n{r.stdout[-5000:]}')
        return r.stdout
    with (build/'compile.log').open('w',encoding='utf-8') as log:
        command('xvlog',['--relax','-i','.',*[x.name for x in sorted(stage.glob('*.v'))]],log)
        command('xvlog',['--relax','--sv','-i','.',*[x.name for x in sorted(stage.glob('*.sv'))]],log)
    for test in a.tests:
        t=time.time()
        with (build/(test+'.log')).open('w',encoding='utf-8') as log:
            command('xelab',['--relax','--debug','typical',test,'-s',test+'_sim'],log)
            output=command('xsim',[test+'_sim','-runall'],log)
        passed=f'SLE_TEST_PASS: {test}' in output and 'Fatal:' not in output and 'ERROR:' not in output
        results.append({'test':test,'passed':passed,'seconds':round(time.time()-t,2)})
        (build/'test_results.json').write_text(json.dumps({'stage':str(stage),'tool':'Vivado 2020.2 XSim','source_hashes':source_hashes,'results':results},indent=2)+'\n',encoding='utf-8')
        print(test,'PASS' if passed else 'FAIL',flush=True)
        if not passed:raise RuntimeError(output[-5000:])
    (build/'test_results.json').write_text(json.dumps({'stage':str(stage),'tool':'Vivado 2020.2 XSim','source_hashes':source_hashes,'results':results},indent=2)+'\n',encoding='utf-8')
    return 0
if __name__=='__main__':raise SystemExit(run())
