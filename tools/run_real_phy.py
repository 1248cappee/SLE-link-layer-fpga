"""Instrument frozen PHY testbenches with the new elastic MAC boundary.

Only isolated TB copies are instrumented; PHY algorithm RTL and original
vectors are byte-identical to docs/phy_source_lock.json.
"""
from pathlib import Path
import subprocess,os,shutil,json,hashlib,re,time,argparse
parser=argparse.ArgumentParser()
parser.add_argument('--native-control',action='store_true',help='Keep original PHY TB control fields; separate baseline evidence')
args=parser.parse_args()
tag='native' if args.native_control else 'contract'
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'external/p101_phy_rf/phy'
build=ROOT/'build';stage=build/'real_phy_stage';stage.mkdir(parents=True,exist_ok=True)
lock=json.loads((ROOT/'docs/phy_source_lock.json').read_text(encoding='utf-8'))
for item in lock['files']:
    p=ROOT/item['relative']
    assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],p
shutil.copytree(source,stage,dirs_exist_ok=True)
for p in (source/'tx/vectors').glob('*.mem'):
    (stage/'vectors').mkdir(exist_ok=True);shutil.copy2(p,stage/'vectors'/p.name)
env=dict(os.environ,PROCESSOR_ARCHITECTURE='AMD64')
def run(tool,args,log):
    binary=Path(r'D:\vivado\Vivado\2020.2\bin')/(tool+'.bat')
    r=subprocess.run(['cmd.exe','/d','/c',str(binary),*args],cwd=stage,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,encoding='utf-8',errors='replace',timeout=1800)
    log.write(r.stdout);log.flush()
    if r.returncode:raise RuntimeError(r.stdout[-7000:])
    return r.stdout
transport=[]
for base in ('rw_ble_bit_stream','rw_ble_lr_fec_dec'):
    for p in (ROOT/base/'verilog/rtl').glob('*.v'):
        shutil.copy2(p,stage/p.name);transport.append(p.name)
control_source=ROOT/'rw_ble_top/verilog/rtl/rw_ble_misc_logic.v'
shutil.copy2(control_source,stage/control_source.name);transport.append(control_source.name)
benches=[]
for suffix in ('type1','type234'):
    p=source/'tx/tb'/f'tb_sle_tx_rx_{suffix}_loopback.sv'
    text=p.read_text(encoding='utf-8')
    expressions={field:re.search(r'\.cfg_'+field+r'\s*\(([^)]*)\)',text).group(1) for field in
                 ['frame_type','ctrl_format','mcs','payload_bytes','frame_crc_mode','ctrl_info_len','ctrl_info_bits']}
    if not args.native_control:
        text=re.sub(r'\.cfg_ctrl_info_bits\s*\([^)]*\)', '.cfg_ctrl_info_bits(mac_ctrl_bits)',text,count=1)
    for port in ['tdata','tkeep','tvalid','tlast','tready']:
        pattern=r'(\.s_payload_'+port+r'\s*\()tx_payload_'+port+r'(\))'
        text,count=re.subn(pattern,r'\1bridge_'+port+r'\2',text)
        assert count==1,(p,port,count)
    insertion='''
    wire [31:0] bridge_tdata; wire [3:0] bridge_tkeep;
    wire bridge_tvalid,bridge_tlast,bridge_tready;
    rw_ble_bit_stream mac_boundary(.clk(clk),.rst_n(rst_n),
      .s_data(tx_payload_tdata),.s_keep(tx_payload_tkeep),.s_valid(tx_payload_tvalid),.s_last(tx_payload_tlast),.s_ready(tx_payload_tready),
      .m_data(bridge_tdata),.m_keep(bridge_tkeep),.m_valid(bridge_tvalid),.m_last(bridge_tlast),.m_ready(bridge_tready));
'''
    insertion+=f'''
    wire [63:0] mac_ctrl_bits;
    wire mac_ctrl_valid; wire [11:0] mac_air_bytes;
    wire [10:0] mac_payload_bytes={expressions['payload_bytes']};
    rw_ble_misc_logic control_pack(.frame_type({expressions['frame_type']}),.control_bits({expressions['ctrl_info_len']}),
      .ctrl_format({expressions['ctrl_format']}),.mcs({expressions['mcs']}),.control_template({expressions['ctrl_info_bits']}),
      .payload_bytes(mac_payload_bytes),.crc_mode({expressions['frame_crc_mode']}),.valid_control(mac_ctrl_valid),
      .air_data_bytes(mac_air_bytes),.native_control_bits(mac_ctrl_bits));
    always @(posedge clk) if(rst_n&&tx_cfg_valid&&!mac_ctrl_valid)$fatal(1,"MAC control validation failed");
'''
    # Insert after the TB's signal declarations. Inserting before declarations
    # makes older XSim create implicit nets for forward-referenced logic vars.
    text,count=re.subn(r'(\s*sle_tx_mac_iq_top\s+)',lambda m:'\n'+insertion+m.group(1),text,count=1)
    assert count==1,p
    out=stage/(p.stem+'_boundary.sv');out.write_text(text,encoding='utf-8');benches.append(out.name)
with (build/'real_phy_compile.log').open('w',encoding='utf-8') as log:
    run('xvlog',['--relax',*transport],log)
    run('xvlog',['--relax','--sv','-f','hw/IPs/Src/PHY/sle_phy_rx/verilog/rtl/sle_phy_rx_rtl.list',
                 *[str(x.relative_to(stage)).replace('\\','/') for x in sorted((stage/'tx/rtl').glob('*.sv'))],*benches],log)
    for suffix in ('type1','type234'):
        run('xelab',['--relax','-L','xpm','-L','unisims_ver',f'tb_sle_tx_rx_{suffix}_loopback','-s',suffix+'_boundary'],log)
results=[]
for frame in range(1,5):
    suffix='type1' if frame==1 else 'type234'
    t=time.time()
    with (build/f'real_phy_{tag}_type{frame}.log').open('w',encoding='utf-8') as log:
        (stage/'plusargs.txt').write_text(f'--testplusarg FRAME_TYPE={frame}\n',encoding='ascii')
        output=run('xsim',[suffix+'_boundary','-runall','--file','plusargs.txt'],log)
    passed=f'[TX-RX-TYPE{frame}][PASS]' in output and 'Fatal:' not in output
    results.append({'frame_type':frame,'passed':passed,'seconds':round(time.time()-t,2)})
    (build/f'real_phy_{tag}_results.json').write_text(json.dumps({'commit':lock['commit'],'control_mode':tag,'scope':'elastic MAC boundary + real TX/RX RTL; not full scheduler or RF acceptance',
        'mac_sources':{name:hashlib.sha256((stage/name).read_bytes()).hexdigest() for name in transport},'results':results},indent=2)+'\n',encoding='utf-8')
    print('Real PHY boundary Type',frame,'PASS' if passed else 'FAIL',flush=True)
if not all(r['passed'] for r in results):raise SystemExit(1)
