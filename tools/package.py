"""Emit filelists, interface changes and per-module requirement/test links."""
from pathlib import Path
import json,re,zipfile,hashlib,csv
ROOT=Path(__file__).resolve().parents[1]
allocation=json.loads((ROOT/'docs/module_allocation.json').read_text(encoding='utf-8'))
contract=json.loads((ROOT/'docs/resource_contract.json').read_text(encoding='utf-8'))
def declarations(text):
    header=text.split(');',1)[0]
    header=re.sub(r'//[^\n]*','',header)
    result={}
    for direction,width,names in re.findall(r'\b(input|output)\s+(?:wire|reg|logic)?\s*(\[[^]]+\])?\s*([A-Za-z_0-9, ]+)',header):
        for n in names.split(','):
            if n.strip():result[n.strip()]={'direction':direction,'width':width or '1'}
    return result
def purpose(name):
    if name.startswith('rw_ble_lr_') or name in ('rw_ble_bit_stream','rw_ble_crc','rw_ble_whitening'):
        return 'External PHY elastic transport boundary; algorithm supplied by the pinned PHY','PHY 6.1/6.9/6.10', ['tb_system','real_phy_type1','real_phy_type2','real_phy_type3','real_phy_type4']
    if name.startswith('rw_ble_event_cntl'):
        return 'Role dispatch, CS validation, event timing, channel scan or co-existence policy','SLE 7; SCH state/mode contract',['tb_system','tb_scheduler','tb_recovery']
    if name.startswith('rw_ble_packet_cntl'):
        return 'Descriptor-chain sequencer, ordered memory access and TX/RX completion','SLE 7.3/9.3',['tb_system','tb_lengths','tb_secure_system','tb_recovery']
    names={
        'rw_ble_reg':('32-bit register / extension bank','SCH register contract',['tb_registers','tb_system']),
        'rw_ble_em_cntl':('128 KiB byte-enabled shared BRAM and fair arbitration','SCH shared-memory contract',['tb_bus','tb_system']),
        'rw_ble_freq_select':('SLE PERM/MAM PRNG and 76-channel remapping','SLE 6.10.3',['tb_auxiliary']),
        'rw_ble_list_search_engine':('Streaming masked whitelist filter','SLE 7.1.5/7.1.6',['tb_auxiliary']),
        'rw_ble_ral_search_engine':('IRK-ID selection and AES/SM4 CMAC identifier resolution','SLE 9.4',['tb_auxiliary','tb_primitives']),
        'rw_ble_misc_logic':('Native PHY control format, full length and MCS packing','SLE 6.4; frozen PHY interface',['tb_control','real_phy_type1','real_phy_type2','real_phy_type3','real_phy_type4']),
        'rw_ble_top_tglp_ext':('Optional rational low-power time retention','SLE time base',['tb_low_power']),
    }
    return names.get(name,('RW architectural integration / explicit handshakes','RW 2.1; SCH all contracts',['tb_system','tb_scheduler','tb_secure_system']))
mapping=[]
with zipfile.ZipFile(ROOT.parent/'BLE.zip') as archive:
    for row in allocation:
        target=ROOT/row['target'];assert target.exists(),target
        new=target.read_text(encoding='ascii');old=archive.read(row['source']).decode('utf-8',errors='replace')
        old_ports,new_ports=declarations(old),declarations(new)
        desc,sections,tests=purpose(row['module'])
        if 'packet_cntl' in row['module'] or row['module'] in ('rw_ble_core','rw_ble_core_cntl','rw_ble_top'):
            tests+=['tb_appendix_f','tb_secure_chain']
        if row['module']=='rw_ble_em_cntl':tests+=['tb_em_reset','tb_board_suite']
        if row['module'] in ('rw_ble_reg','rw_ble_top','rw_ble_core','rw_ble_core_cntl','rw_ble_packet_cntl'):
            tests+=['tb_board','tb_board_suite']
        refs=[]
        if row['module']=='rw_ble_reg':refs=[dict(book='01',sheet='字段定义',rows=[6,8,9,10,11,12,13,14,17,18,19,20,21,22,23,24,25,26,27,30,31,32,33,34,35,36,41])]
        elif 'em_cntl' in row['module']:refs=[dict(book='02',sheet='对象布局',rows=[5,6,7,8,14,15,16,17])]
        elif 'packet_cntl' in row['module']:refs=[dict(book='02',sheet='对象字段',rows='All defined TX/RX/CS fields used; see INTERFACE.md'),dict(book='03',sheet='状态时序',rows=[18,19,20,21,55,56,57,61,62])]
        elif 'event_cntl' in row['module']:refs=[dict(book='03',sheet='状态时序',rows=[18,19,20,21,54,55,56,57,61])]
        else:refs=[dict(book='03',sheet='状态时序',rows=[6,7,8,9,15,51,53,54,57,65,67])]
        mapping.append(dict(row,purpose=desc,sections=sections,tests=tests,ports=new_ports,
            resource_row_references=refs,
            ports_added=sorted(new_ports.keys()-old_ports.keys()),ports_removed=sorted(old_ports.keys()-new_ports.keys()),
            ports_changed={k:{'old':old_ports[k],'new':new_ports[k]} for k in new_ports.keys()&old_ports.keys() if new_ports[k]!=old_ports[k]},
            resource_sources=['01_SLE_SCH_寄存器表_v1.0.xlsx','02_SLE_SCH_共享内存表_v1.0.xlsx','03_SLE_SCH_状态时序表_v1.0.xlsx']))
(ROOT/'docs/module_mapping.json').write_text(json.dumps(mapping,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
rtl=sorted(p for p in ROOT.rglob('*.v') if not {'external','build','verification','board'}&set(p.relative_to(ROOT).parts))
(ROOT/'rtl.f').write_text('+incdir+common/rtl\n'+'\n'.join(str(p.relative_to(ROOT)).replace('\\','/') for p in rtl)+'\n',encoding='ascii')
board_rtl=sorted((ROOT/'board/rtl').glob('*.v'))
if board_rtl:
    (ROOT/'board.f').write_text((ROOT/'rtl.f').read_text()+'+incdir+board/rtl\n'+'\n'.join(p.relative_to(ROOT).as_posix() for p in board_rtl)+'\n',encoding='ascii')
groups={x['target'].split('/')[0] for x in mapping}
for group in sorted(groups):
    rows=[r for r in mapping if r['target'].startswith(group+'/')]
    root=ROOT/group
    (root/'rtl.f').write_text('\n'.join(r['target'] for r in rows)+'\n',encoding='ascii')
    (root/'README.md').write_text('# '+group+'\n\n'+ '\n\n'.join('`'+r['module']+'`: '+r['purpose']+'. Tests: '+', '.join(r['tests'])+'.' for r in rows)+'\n\nRun all commands from the SLE root. Shared dependencies are in ../rtl.f; source-of-truth interface changes are in ../docs/module_mapping.json.\n',encoding='utf-8')
offsets=[]
registers=contract['01_SLE_SCH_寄存器表_v1.0.xlsx']['寄存器目录']
for row in registers:
    cells=row['cells'];v=cells.get('B','')
    if isinstance(v,str) and re.fullmatch('[0-9A-Fa-f]{3}h',v):offsets.append(int(v[:-1],16))
assert len(offsets)==104
(ROOT/'verification/register_offsets.mem').write_text('\n'.join(f'{v:03x}' for v in offsets)+'\n',encoding='ascii')
(ROOT/'docs/build_sources.json').write_text(json.dumps({str(p.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in rtl},indent=2)+'\n',encoding='utf-8')
print('Packaged',len(mapping),'RW counterparts,',len(rtl),'total RTL sources, and',len(offsets),'register offsets.')
