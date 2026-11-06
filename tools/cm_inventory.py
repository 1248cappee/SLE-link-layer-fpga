"""Inventory the immutable CM reference and map it to SLE implementations.

Never extract reference RTL into a build source directory.
"""
from pathlib import Path
import hashlib, json, zipfile, re

ROOT = Path(__file__).resolve().parents[1]
audio = {'rw_cm_aulaw','rw_cm_pcm','rw_cm_audio_path',
         'rw_cm_audio_em_access_cntl','rw_cm_audio_sequencer','rw_cm_cvsd'}
special_radio = {'rw_cm_df_cntl_if','rw_cm_icytrx_v2_cntl','rw_cm_ripple_cntl',
 'rw_cm_correlator','rw_cm_ble_iso_if','rw_cm_edr_if','rw_cm_extrc_cntl',
 'rw_cm_serial_txrx_if','rw_cm_calypso_cntl','rw_cm_btipt_cntl'}

def duties(module,group):
    if group=='rw_cm_crypto_engine':
        names={
          'rw_cm_aes_sbox':'AES forward octet substitution',
          'rw_cm_aes_shiftrows':'AES column-order row permutation',
          'rw_cm_aes_mixcolumns':'AES GF(256) column transform',
          'rw_cm_aes_keyexpansion':'AES-128 next-round key and Rcon expansion',
          'rw_cm_aes_fsm':'Accepted-start ownership, ten-round sequencing and one-cycle completion',
          'rw_cm_aes_cipher_decipher':'Forward round chain for both CCM directions; configurable rounds per cycle',
          'rw_cm_aes_top':'Captured AES block/key state and round-control/datapath integration',
          'rw_cm_ccm_top':'Payload BRAM, CTR/CBC-MAC sequencing, four-octet MIC and ordered result',
          'rw_cm_crypto_engine':'Software/packet-compatible CCM engine boundary'}
        name=names.get(module,'Forward transform shared with the corresponding non-bidirectional CM module')
        return name,'SLE 9.3.1.3 data-plane security; applicable AES/SM4 vectors','CM-SECURITY'
    if group=='rw_cm_activity_scheduler':
        return '16-entry ownership, fixed submit lead, five-grid alignment, priority arbitration and ordered terminal writeback','SCH 03 submission/state/terminal contract; SLE 7 activity timing','CM-GRID'
    if group in {'rw_cm_ahb_if','rw_cm_xbar_if'}:
        return 'Host decode and separate register/EM transaction completion; byte enables, wait/error and reset epochs','SCH 01 access attributes; SCH 02 EM address and completion contract','CM-BUS'
    if group=='rw_cm_misc':
        return 'Synchronizer/edge or acknowledged event transfer; bundled-data consistency and reset release','Implementation CDC contract; CM_INTERFACE.md clocks and resets','CM-CDC'
    if group=='rw_cm_timing_gen':
        return '125us base / 0.5us fine time, retention handshake, wake control or low-rate resynchronization','SCH 03 base time; CM_INTERFACE.md digital sleep/retention contract','CM-SLEEP'
    if group=='rw_cm_diag_cntl':
        return 'All-client EM counters, frozen statistics, range and first-fault capture','SCH 01 diagnostic directory; CM ABI 1.1 0x540..0x564','CM-DIAG'
    if group=='rw_cm_int_cntl':
        return 'Sticky status/mask/W1C handling and IRQ aggregation; simultaneous set wins clear','SCH 01 interrupt attributes; CM ABI 1.1 independent interrupt bank','CM-IRQ'
    if group in {'rw_cm_coex_if','rw_cm_wlan_coex_cntl'}:
        return 'SLE request/priority/grant/denial and packet-boundary withdrawal','CM_INTERFACE.md coexistence contract; frozen PHY packet stop/drain interface','CM-COEX'
    if group=='rw_cm_radio_cntl':
        return 'Native SLE configuration/data/result boundary with pending-read ownership and elastic RX response buffering','Frozen SLE PHY mailbox/config/stream interface; no RF algorithm implementation','CM-RADIO'
    return 'Not applicable to selected SLE/P101 profile','Selected implementation scope; exclusion reason is authoritative','EXCLUDED'

def inventory():
    rows=[]
    with zipfile.ZipFile(ROOT.parent/'CM.zip') as z:
        for n in sorted(z.namelist()):
            if not n.startswith('CM/') or not n.endswith('.v'): continue
            group=n.split('/')[1]; module=Path(n).stem
            target=ROOT/n
            excluded = group in audio or group=='rw_cm_mws_coex_cntl' or module in special_radio
            reason = ('Bluetooth audio codec/PCM is outside the SLE link-layer contract' if group in audio else
                      'External MWS/WCI platform interface is outside the selected P101 configuration' if group=='rw_cm_mws_coex_cntl' else
                      'Bluetooth/vendor radio algorithm replaced by the frozen external SLE PHY contract' if module in special_radio else '')
            alternate=None
            forward_alternatives={
                'rw_cm_aes_bidir_sbox':'rw_cm_aes_sbox',
                'rw_cm_aes_bidir_shiftrows':'rw_cm_aes_shiftrows',
                'rw_cm_aes_bidir_mixcolumns':'rw_cm_aes_mixcolumns'}
            if module in forward_alternatives:
                alternate=f'CM/rw_cm_crypto_engine/verilog/rtl/{forward_alternatives[module]}.v'
                reason='Forward transform is shared with the corresponding CM module; SLE CCM RX uses CTR, not inverse AES. No inverse-mode capability is advertised.'
            if group=='rw_cm_timing_gen' and module in {'rw_cm_timing_gen_audio','rw_cm_timing_gen_pcmref_timing','rw_cm_timing_gen_abtrain'}:
                excluded=True;reason='Bluetooth audio/AB train reference is not an SLE timing function'
            if module in {'rw_cm_aes_fsm_decipher','rw_cm_aes_keyexpansion_decipher','rw_cm_aes_invmixcolumns'}:
                excluded=True;reason='AES inverse-block datapath is not used by CCM payload decryption; the selected SLE data-plane uses the forward AES/SM4 CTR primitive'
            path=target.relative_to(ROOT).as_posix() if target.exists() else alternate
            state='EXCLUDED_BY_PROFILE' if excluded else 'IMPLEMENTED' if target.exists() else 'MAPPED_EQUIVALENT' if alternate else 'PENDING'
            if excluded:path=None
            def ports(text):
                text=re.sub(r'/\*.*?\*/','',text,flags=re.S)
                text=re.sub(r'//[^\n]*','',text).split(');',1)[0]
                result={}
                for direction,width,names in re.findall(r'\b(input|output)\s+(?:wire|reg)?\s*(\[[^]]+\])?\s*([A-Za-z_0-9, ]+)',text):
                    for p in names.split(','):
                        if p.strip():result[p.strip()]={'direction':direction,'width':width or '1'}
                return result
            reference_text=z.read(n).decode('utf-8',errors='replace')
            old_ports=ports(reference_text)
            new_ports=ports((ROOT/path).read_text()) if path else {}
            tests=(['tb_bus','tb_board_axi','tb_board_suite'] if group in {'rw_cm_ahb_if','rw_cm_xbar_if'} else
                   ['tb_cm_cipher','tb_crypto','tb_stream_crypto','tb_cm_system','tb_board_suite'] if group=='rw_cm_crypto_engine' else
                   ['tb_cm_cdc'] if group=='rw_cm_misc' else ['tb_cm','tb_cm_system','tb_cm_sleep','tb_cm_day','tb_board_suite'])
            duty,reference,requirement=duties(module,group)
            original=re.search(r'//\s*Description\s*:\s*(.*?)(?=//\s*Simulation Notes)',reference_text,re.S)
            original_duty=re.sub(r'\s*//\s*',' ',original.group(1)).strip() if original else 'See immutable reference module interface'
            rows.append(dict(source=n,module=module,source_sha256=hashlib.sha256(z.read(n)).hexdigest(),
                status=state,target=path,reason=reason,
                original_duty=original_duty,sle_duty=reason if excluded else duty,
                requirement_id='EXCLUDED' if excluded else requirement,
                sle_reference=reference,
                tests=[] if excluded else tests,
                reference_ports_macro_union=old_ports,ports=new_ports,
                ports_added=sorted(new_ports.keys()-old_ports.keys()),ports_removed=sorted(old_ports.keys()-new_ports.keys()),
                ports_changed={k:{'old':old_ports[k],'new':new_ports[k]} for k in sorted(old_ports.keys()&new_ports.keys()) if old_ports[k]!=new_ports[k]},
                resource_contracts=['01: register directory rows 17-24,45-50,78-80; original defined fields unchanged',
                                    '02: ET16B/CS146B/TX16B/RX28B and pointer contracts unchanged',
                                    '03: base fine/slot time, commit, ownership, stop and terminal ordering'],
                port_contract='CM_INTERFACE.md; module ANSI declaration is authoritative'))
    assert len(rows)==95
    (ROOT/'docs/cm_mapping.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('CM mapping:',len(rows),{s:sum(r['status']==s for r in rows) for s in sorted({r['status'] for r in rows})})

if __name__=='__main__':inventory()
