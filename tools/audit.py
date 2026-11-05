"""Read evidence, verify provenance, emit bounded acceptance / coverage reports."""
from pathlib import Path
import json,hashlib,re
ROOT=Path(__file__).resolve().parents[1]
def read(name):return json.loads((ROOT/name).read_text(encoding='utf-8'))
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def fresh(hashes):return bool(hashes) and all((ROOT/n).exists() and digest(ROOT/n)==h for n,h in hashes.items())
inputs=read('docs/source_manifest.json')
assert all(digest(ROOT.parent/n)==r['sha256'] for n,r in inputs.items()),'Input material changed'
lock=read('docs/phy_source_lock.json')
assert all(digest(ROOT/r['relative'])==r['sha256'] for r in lock['files']),'Frozen PHY changed'
mapping=read('docs/module_mapping.json');assert len(mapping)==43
for r in mapping:
    text=(ROOT/r['target']).read_text(encoding='ascii')
    assert re.search(r'\bmodule\s+'+r['module']+r'\b',text),r['target']
tests=read('build/test_results.json')
required=['tb_primitives','tb_crypto','tb_stream_crypto','tb_time_fifo','tb_registers','tb_control','tb_low_power','tb_bus','tb_auxiliary','tb_system','tb_scheduler','tb_recovery','tb_lengths','tb_secure_system','tb_appendix_f','tb_secure_chain','tb_resources','tb_submit_threshold']
passed={r['test'] for r in tests['results'] if r['passed']}
assert set(required)<=passed and fresh(tests['source_hashes']),'Model tests missing, failed or stale'
for t in required:
    log=(ROOT/'build'/f'{t}.log').read_text(encoding='utf-8',errors='replace')
    assert f'SLE_TEST_PASS: {t}' in log and 'Fatal:' not in log and 'ERROR:' not in log,t
ooc=read('build/result.json')
ooc_fresh=ooc.get('top')=='rw_ble_top' and fresh(ooc.get('source_hashes',{}))
ooc_pass=ooc_fresh and ooc['setup_slack_ns']>=0 and ooc['hold_slack_ns']>=0 and ooc['blackboxes']==0 and ooc['latches']==0
phy={}
for mode in ['native','contract']:
    result=read(f'build/real_phy_{mode}_results.json')
    assert result['commit']==lock['commit'] and len(result['results'])==4
    for name,h in result['mac_sources'].items():
        paths=[p for p in ROOT.rglob(name) if not {'external','build'}&set(p.relative_to(ROOT).parts)]
        assert len(paths)==1 and digest(paths[0])==h,('PHY boundary evidence stale',name)
    phy[mode]=result['results']
contract=read('docs/resource_contract.json')
coverage=[]
def group(identifier,book,sheet,lo,hi,implementation,ts,scope='IMPLEMENTED_DIRECTED_TESTS'):
    key=next(n for n in contract if n.startswith(book))
    rows=[r for r in contract[key][sheet] if lo<=r['row']<=hi]
    coverage.append(dict(id=identifier,source=key,sheet=sheet,rows=[r['row'] for r in rows],requirements=rows,implementation=implementation,tests=ts,status=scope))
group('REG-DIRECTORY','01','寄存器目录',5,200,'rw_ble_reg; undefined legacy fields RAZ/W0, nonzero writes BAD_CMD',['tb_registers'],'DIRECTORY_DECODE_AND_RESET_TESTED')
for ident,lo,hi,ts in [('REG-CONTROL',6,14,['tb_registers','tb_system','tb_recovery']),('REG-TIME',17,27,['tb_time_fifo','tb_registers']),('REG-EVENT',30,36,['tb_scheduler','tb_lengths','tb_recovery'])]:
    group(ident,'01','字段定义',lo,hi,'rw_ble_reg; common timing/interrupt/FIFO',ts)
group('HOST-OWNERSHIP','01','字段定义',39,42,'AHB/XBAR local decode; host barriers/callbacks are software obligations',['tb_bus','tb_system'],'HW_DIRECTED_TESTS_PLUS_SW_CONTRACT')
group('EM-LAYOUT','02','对象布局',5,17,'rw_ble_em_cntl; rw_ble_packet_cntl; extension metadata, original strides unchanged',['tb_bus','tb_lengths','tb_control','tb_resources'])
group('EM-FREEZE','02','对象布局',18,18,'owned protects extension bank; host must freeze all referenced EM objects',[],'SOFTWARE_OWNERSHIP_CONTRACT')
group('OBJECT-FIELDS','02','对象字段',4,300,'Original defined fields accessed by packet controller; unspecified business fields supplied by extension window',['tb_system','tb_lengths','tb_secure_system'],'IMPLEMENTED_SUBSET_AND_EXPLICIT_EXTENSION_MAPPING')
group('TIME-PARAMETERS','03','状态时序',6,15,'20MHz, /10 fine, 250 ticks/slot, 30-bit slot, 16 ET; T-8 programmer notification is software configured',['tb_time_fifo','tb_registers','tb_scheduler'])
group('STATE-MODE','03','状态时序',18,29,'rw_cm_activity_scheduler + packet/event controllers',['tb_system','tb_scheduler','tb_recovery'])
group('EVENT-REASON','03','状态时序',32,47,'sle_defs.vh; FIFO snapshot; ordered DONE writeback and terminal',['tb_scheduler','tb_lengths','tb_recovery'])
group('PUBLISH-ARBITRATE','03','状态时序',50,55,'Atomic READY commit timestamp; half-range; priority tournament; MIN/MAX',['tb_scheduler','tb_secure_system','tb_submit_threshold'])
group('COMPLETE-CANCEL','03','状态时序',56,62,'Ordered packet facts/terminal; cancel waits packet boundary, memory and genuine PHY quiescence',['tb_system','tb_recovery','tb_secure_chain'])
group('CLOCK-RECOVERY','03','状态时序',63,67,'Time load/timer/overflow recovery; programmer callbacks and ASAP before READY are software',['tb_time_fifo','tb_registers','tb_recovery'],'HW_DIRECTED_TESTS_PLUS_SW_CONTRACT')
coverage += [dict(id='SECURITY-APPENDIX-F',source='SLE PDF pp535-536, printed527-528',implementation='AES/SM4 CCM, 4B MIC, AAD zero, separate TX/RX39-bit counters',tests=['tb_appendix_f','tb_crypto','tb_stream_crypto','tb_secure_chain','tb_secure_system'],status='DIRECTED_TESTS_PASS'),
dict(id='REAL-PHY',source=lock['commit'],implementation='Pinned PHY with transport/control packing in instrumented TB copies',tests=['real_phy_contract_type1','real_phy_contract_type2','real_phy_contract_type3','real_phy_contract_type4'],status='PARTIAL_FAIL_TYPE3_TYPE4_AND_MISSING_MILESTONES'),
dict(id='OTHER-NONCE-PROFILES',implementation='System-slot/day-count nonce for other link types; not automatically generated by this profile',tests=[],status='NOT_IMPLEMENTED'),
dict(id='RF-BOARD',implementation='P101 PS/RF/clock/CDC/pin integration and on-board test',tests=[],status='NOT_TESTED')]
(ROOT/'docs/requirements_coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report=dict(input_integrity=True,phy_integrity=True,rw_counterparts=43,rtl_files=len(read('docs/build_sources.json')),contract_model_tests=len(required),contract_model='PASS',ooc='PASS' if ooc_pass else 'MISSING_OR_STALE',ooc_details=ooc,real_phy_boundary=phy,full_real_phy_integration='BLOCKED_PHY_01_02_03_06',rf_board='NOT_TESTED',coverage='Directed evidence; not formal or complete protocol conformance')
(ROOT/'docs/acceptance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
util=(ROOT/'build/utilization_routed.rpt').read_text(encoding='utf-8',errors='replace') if ooc_pass else ''
def used(name):
    m=re.search(r'\|\s*'+re.escape(name)+r'\s*\|\s*(\d+)\s*\|',util)
    return m.group(1) if m else '未核验'
text=f'''# 验收与证据边界

本报告由 tools/audit.py 根据日志和源码哈希生成。输入资料及固定PHY的{len(lock['files'])}个文件完整性通过。43个RW原模块全部有同目录/同文件名/同模块名对应，完整自有RTL{report['rtl_files']}个文件。

## 链路层合同模型

{len(required)}个XSim测试平台通过：{', '.join(required)}。build/test_results.json保存全部被测源哈希；原始日志在build同名文件。测试覆盖附录F完整AES/SM4示例、独立库CCM向量、长包/反压、原对象边界、四种模式、16项竞争、取消/恢复、FIFO溢出、CRC/MIC/重复失败和独立安全链计数。

这些是定向仿真证据，不是全部状态空间的形式证明。requirements_coverage.json列出原表工作表/行号、实现和用例；目录地址读写验证不能替代所有业务组合覆盖。尚未穷举全部保留位、每个角色组合、取消同拍竞争、各信道/MCS组合及39位计数耗尽。共享EM冻结、屏障、回调和T−8准备属于明确的软件合同。

## 综合及OOC

状态：**{report['ooc']}**。顶层rw_ble_top，器件xc7z100ffg900-2，20MHz，输入/输出延时5ns。自有链路层的setup slack：{ooc.get('setup_slack_ns')}ns；hold slack：{ooc.get('hold_slack_ns')}ns；LUT：{used('Slice LUTs')}；寄存器：{used('Slice Registers')}；RAMB36：{used('RAMB36/FIFO*')}；DSP：{used('DSPs')}。黑盒/锁存器检查见build/result.json及综合日志。

只有状态PASS且源哈希新鲜时，以上数值才归属于当前工程。OOC默认不包括外部PHY、PS/AXI系统、真实I/O引脚和板级时钟。异步复位路径为false path；其余数据路径使用50ns时钟、5ns端口约束。OOC报告有未定义板级clock-buffer位置/端口部分布线的警告；未进行板级CDC/复位释放及物理I/O签核。

DRC尚有31条Warning，包含RAMB36控制寄存器异步复位检查（报告20条达到规则显示上限）、DSP流水建议、无负载端口及缺少PS7。时序PASS并不代表这些告警已全部关闭。软复位先等待EM空闲再清ET/复位；硬复位后软件必须重新初始化引用对象。板级复位实现仍需检查BRAM控制信号的同步性及复位释放，不得把当前OOC当作板级硬件签核。

## 真实PHY与射频

原始PHY控制字段基线：Type1/2/3/4均通过。新MAC控制字段合同模式：Type1/2通过，Type3/4失败，详见PHY-06。两种模式都使用新同名弹性数据封装和固定版本真实TX/RX算法，测试只覆盖原始自环向量；不代表2047B各帧型/MCS矩阵通过。

完整调度+真实PHY：**受PHY-01/02/03/06阻塞，未通过验收**。真实同步时间、停稳和空口起止没有用常量或延时替代。射频上板：**未测试**。ModelSim未作为本次通过依据。

## 未宣称实现的功能

软件协商、资源分配、密钥派生和ARQ策略不编写C程序。辅助过滤/CMAC解析通过显式接口提供，尚未自动绑定任意业务PDU解析；HMAC-SM3、多于16B的CMAC及其他频段没有宣告支持。系统槽号/天数nonce profile尚未自动实现，需要新增接口/配置后另行验证。因而当前交付是可综合、可复现测试的链路层合同实现，不能标记为全部SLE规范业务认证通过。
'''
(ROOT/'docs/ACCEPTANCE.md').write_text(text,encoding='utf-8')
print(json.dumps({k:report[k] for k in ['rw_counterparts','rtl_files','contract_model_tests','contract_model','ooc','full_real_phy_integration','rf_board']},ensure_ascii=False,indent=2))
if not ooc_pass:raise SystemExit(2)
