"""Accept new CM functionality only with matching source/bit/three real rounds."""
from pathlib import Path
import json,csv,re,hashlib,datetime
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/board'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def gated_capture(path):
    values=[]
    with path.open(newline='') as fp:
        rows=csv.reader(fp);header=next(rows)
        cols=[i for i,n in enumerate(header) if 'trace' in n.lower() or 'probe0' in n.lower()]
        assert len(cols)==1,header
        for row in rows:
            if len(row)<=cols[0]:continue
            x=row[cols[0]].strip().replace('_','')
            if re.fullmatch('[0-9a-fA-F]+',x):values.append(int(x,16))
    segments=[];run=[]
    for v in values:
        state=(v>>257)&15;ce=(v>>256)&1;counter=(v>>325)&0xffffffff
        if state==3 and ce==0:run.append(counter)
        elif run:segments.append(run);run=[]
    if run:segments.append(run)
    assert segments,'No gated interval in ILA'
    segment=max(segments,key=len)
    assert len(segment)>=20,len(segment)
    assert len(set(segment[4:]))==1,'Main clock counter moved while gated'
    return {'gated_samples':len(segment),'main_clock_counter_stable':True}

def main(skip_pressure=False):
    from warnings_report import main as review_warnings
    warning_review=review_warnings()
    from report import main as base_report
    base_ok=base_report()==0
    base_status=json.loads((OUT/'acceptance.json').read_text())
    mapping=json.loads((ROOT/'docs/cm_mapping.json').read_text(encoding='utf-8'))
    mapped=len(mapping)==95 and all(r['status']!='PENDING' for r in mapping)
    expected=set(json.loads((ROOT/'board/cases/coverage.json').read_text())['cases'])
    image=digest(OUT/'sle_board.bit');rounds=[]
    for i in range(1,4):
        folder=OUT/'rounds'/str(i);path=folder/'board_results.json'
        if not path.exists():rounds.append({'round':i,'passed':False,'reason':'missing hardware run'});continue
        report=json.loads(path.read_text())
        passed={r['name'] for r in report['cases'] if r['passed']}
        ok=report.get('bit_sha256')==image and passed==expected and 'SLE_VOLATILE_PROGRAM_PASS' in (folder/'program.log').read_text(errors='replace')
        ok=ok and (folder/'ps_init.log').exists() and 'SLE_PS_INIT_PASS' in (folder/'ps_init.log').read_text(encoding='utf-8-sig',errors='replace')
        ok=ok and (folder/'ps_post.log').exists() and 'SLE_PS_CLOCK_INIT_PASS' in (folder/'ps_post.log').read_text(encoding='utf-8-sig',errors='replace')
        capture=None
        try:capture=gated_capture(folder/'ila_cm_sleep_timer.csv')
        except Exception as e:ok=False;capture={'error':str(e)}
        rounds.append({'round':i,'passed':ok,'cases_passed':len(passed),'gate_ila':capture,'started_utc':report.get('started_utc')})
    pressure_path=OUT/'board_pressure.json'
    try:pressure=json.loads(pressure_path.read_text()) if pressure_path.exists() else {}
    except (ValueError,OSError):pressure={'status':'INCOMPLETE_LOG_NOT_ACCEPTED'}
    pressure_ok=pressure.get('bit_sha256')==image and len(pressure.get('cases',[]))==1 and all(r['passed'] for r in pressure.get('cases',[]))
    if pressure_ok:
        pressure_ok=pressure['cases'][0].get('sequence_cycles',0)>=36000000000 and pressure.get('elapsed_wall_seconds',0)>=1799
    functional_ok=mapped and base_ok and all(r['passed'] for r in rounds)
    result={'scope':'SLE_CM_DIGITAL_NO_PHY','bit_sha256':image,'cm_mapping_complete':mapped,'simulation_and_implementation_passed':base_ok,
      'cm_function_implementation_completed':mapped and base_status['simulation_passed'],
      'simulation_regression_passed':base_status['simulation_passed'],
      'p101_full_board_implementation_passed':base_status['implementation_present'],
      'base_and_cm_board_passed':base_status['base_board_passed'] and base_status['closed_loop_board_passed'] and all(r['passed'] for r in rounds),
      'tester_sleep_board_passed':base_ok and all(r['passed'] for r in rounds),
      'tester_sleep_pressure_board_passed':all(r['passed'] for r in rounds) and pressure_ok,
      'download_rounds':rounds,'pressure_30min_passed':pressure_ok,'tool_warning_counts':warning_review['counts'],'real_phy_tested':False,'rf_tested':False,
      'pressure_required_for_requested_scope':not skip_pressure,
      'pressure_status':'USER_EXCLUDED' if skip_pressure else 'PASS' if pressure_ok else pressure.get('status','NOT_PASSED'),
      'cm_functional_acceptance_passed':functional_ok,
      'requested_scope_passed':functional_ok and (skip_pressure or pressure_ok),
      'passed':functional_ok and pressure_ok}
    (OUT/'cm_acceptance.json').write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    implementation=json.loads((OUT/'implementation.json').read_text())
    text='''# SLE CM架构与P101数字板测验收

范围：CM架构参考下的新SLE公共模块，P101 xc7z100ffg900-2，20MHz，数字接口测试器。
真实PHY、射频、独立低速晶振及功耗测量均不属于本次验收。

'''
    text+=f"本次要求的CM功能验收：**{'PASS' if result['requested_scope_passed'] else '尚未完成'}**。源码与镜像以 `build/board/manifest.json` 为准。\n\n"
    text+=f"原含30分钟压力的完整验收：{'PASS' if result['passed'] else '未通过全部条件'}。压力状态：{result['pressure_status']}。\n\n"
    if skip_pressure:text+='用户已要求停止压力测试，本次未重启；这项排除不作为压力通过证明。\n\n'
    text+=f"CM映射95项，原BLE对应43项；当前全部仿真和实现证据一致：{base_ok}。板测三轮："+', '.join(str(r['passed']) for r in rounds)+f"；30分钟压力：{pressure_ok}。\n\n"
    text+=f"setup余量 {implementation['setup_slack_ns']}ns，hold余量 {implementation['hold_slack_ns']}ns。镜像SHA256：`{image}`。\n\n"
    for label,field in [('CM架构映射与本轮SLE功能实现完成','cm_function_implementation_completed'),('仿真回归通过','simulation_regression_passed'),('P101完整板级实现通过','p101_full_board_implementation_passed'),('基础与CM功能板测通过','base_and_cm_board_passed'),('接口测试器闭环及休眠循环（不含长压力）通过','tester_sleep_board_passed'),('原含30分钟压力的组合验收通过','tester_sleep_pressure_board_passed')]:
        text+=f"- {label}：{'PASS' if result[field] else '尚未完成'}。\n"
    text+='\n'
    text+='''每轮执行完整资源合同和CM场景，包含128KiB EM、四模式、长度边界、安全/取消/溢出恢复、五种调度粒度、499/500/501提交，以及10,000次休眠。每次休眠均检查实际主时钟计数停止/恢复、时间单调及EM保留。CRC/AES-MIC/SM4-MIC失败后的下一任务使用保留状态执行，邮箱ACK计数必须达到2，避免用复位代替恢复。

保留的压力程序设计门槛为不少于36,000,000,000个20MHz时钟，重复执行安全四模式、取消、共存撤销和休眠；本次是否执行及通过以开头的pressure_status为准。TX逐字节与电脑独立库预装的密文比较；RX逐轮检查MIC/交付和数据；每轮检查事件顺序。重复帧是相同公开测试向量，不宣称生产环境新消息可复用Nonce。

功能证据：`build/test_results.json`、`build/board/board_results.json`、`build/board/rounds/1..3/`及每场景ILA CSV。若重新授权并执行长压力，其结果单列`build/board/board_pressure.json`。先前被用户停止的r3压力资料保存在`build/board/history/r3_user_stopped_pressure/`，不作为当前镜像通过证明。重现入口为 `tools/sim.ps1`、`board/tools/build.ps1`、`board/tools/accept_cm.ps1 -SkipPressure`。

时隙/天数Nonce当前用于单帧TX或RX；链式、连续和双向安全活动使用载荷计数配置，硬件拒绝可能重复Nonce的组合。HMAC-SM3、配对和密钥派生未实现。低速参考由板内产生并由AON相位校正，结果不代表独立晶振精度或整机低功耗达标。

DRC、CDC、时序完整性及方法学原始报告均保留。下载前脚本拒绝自有逻辑组合驱动异步复位的报告；调试IP内部的剩余建议须结合原报告解释，不作形式化可靠性签核。默认只进行易失性FPGA下载，未写入QSPI。

剩余每一条DRC/方法学告警及影响判断见CM_TOOL_WARNINGS.md，结构化内容见build/board/warning_assessments.json。故障修复经过见CM_BOARD_ISSUES.md。
'''
    (ROOT/'docs/CM_ACCEPTANCE.md').write_text(text,encoding='utf-8')
    print(json.dumps(result,indent=2,ensure_ascii=False))
    return 0 if result['requested_scope_passed'] else 1
if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser()
    parser.add_argument('--skip-pressure',action='store_true',help='Explicit user-scoped functional acceptance; never marks pressure passed')
    raise SystemExit(main(parser.parse_args().skip_pressure))
