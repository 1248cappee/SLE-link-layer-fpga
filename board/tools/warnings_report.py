"""Explain each remaining implementation check; never waive a rule."""
from pathlib import Path
import re,json,hashlib,collections
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'build/board'
EXPLANATIONS={
 'LUTAR-1':'Vivado生成的XSDBM读/写FIFO内部复位路径。属于调试IP，未通过屏蔽规则处理；自有RTL已经改为寄存器输出复位。此项仍有工具提示的毛刺风险，本轮数字测试只能提供功能证据，不能替代器件级可靠性签核。',
 'PDRC-190':'XSDBM状态同步链未放在同一SLICE，可能影响亚稳态裕量。保留原厂调试IP实现与约束，结合CDC安全分类、实际JTAG/ILA多轮测试判断本轮用途；不宣称完成MTBF签核。',
 'RTSTAT-10':'JTAG/XSDBM中的未使用控制/FIFO标志没有可路由负载，属于未消费的调试输出；没有自有链路层有效数据路径。',
 'REQP-165':'JTAG AXI FIFO使用WRITE_FIRST。读写地址由原厂FIFO指针控制，测试RTL不能驱动内部RAM地址；保留原厂模式，通过完整主机读写和多轮功能测试检查本次使用，不将其描述为形式化碰撞证明或已通过被取消的长压力测试。',
 'REQP-181':'JTAG AXI命令FIFO使用WRITE_FIRST，处理与REQP-165相同；该项不是此前自有BRAM异步控制告警。',
}
def main():
 entries=[]
 for file in ('drc.rpt','methodology.rpt'):
  text=(OUT/file).read_text(errors='replace')
  matches=list(re.finditer(r'(?m)^([A-Z]+-\d+#\d+)\s+(Warning|Advisory)\s*$',text))
  for i,m in enumerate(matches):
   body=text[m.end():matches[i+1].start() if i+1<len(matches) else len(text)].split('Related violations:',1)[0].strip()
   rule=m.group(1).split('#')[0]
   assert rule in EXPLANATIONS,('Unreviewed tool rule',rule)
   assert 'board_i/test_core/' not in body,('Own RTL warning requires correction',m.group(1))
   assert any(p in body for p in ('dbg_hub/','board_i/jtag/','board_i/ila/')),('Unexpected warning owner',m.group(1))
   cells=re.findall(r'(?:dbg_hub|board_i/(?:jtag|ila))/[^\s,]+',body)
   entries.append(dict(id=m.group(1),severity=m.group(2),report=file,first_cell=cells[0] if cells else '',detail=body,assessment=EXPLANATIONS[rule]))
 image=hashlib.sha256((OUT/'sle_board.bit').read_bytes()).hexdigest()
 result=dict(bit_sha256=image,own_rtl_warnings=0,counts=dict(collections.Counter(e['id'].split('#')[0] for e in entries)),entries=entries)
 (OUT/'warning_assessments.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 text='# 本轮实现告警逐项说明\n\n镜像SHA256：`'+image+'`。以下条目未屏蔽、未降级；原始报告保留。原先自有BRAM异步控制问题已通过同步地址/写控制修复，BRAM内容不整块复位。\n\n'
 for e in entries:
  text+=f"- **{e['id']} ({e['severity']})**：`{e['first_cell']}`。{e['assessment']} 原文见 `build/board/{e['report']}`。\n\n"
 text+='''## 综合阶段的其他提示

Vivado 2020.2将显式SIM_DEVICE=7SERIES的BUFGCE展开为BUFGCTRL时，仍可能提示展开后原语的默认SIM_DEVICE值并自动改成7SERIES。该提示不作为属性已经正确的证明；后实现check_debug_clocks.tcl要求真实门控原语SIM_DEVICE=7SERIES、专用同步CE配置以及JTAG/ILA常开时钟连接，并保存debug_clocks.rpt。未屏蔽此工具消息。

Synth 8-589是四态兼容写法===在硬件中转为二态比较：实际输入由已连接寄存器或有效接口驱动，硬件不依赖X值判决。Synth 8-7129保留CS固定布局后出现未使用端口/位提示；未用位没有挪用为新业务字段。Synth 8-6841是大深度字节写RAM的分解性能建议，地址范围与所有字节通道仍由仿真及完整EM板测验证。当前CCM私有RAM另有定向BRAM及REQP-1839/1840零违规证据，不再使用LUTRAM回退。原始综合日志随implementation_logs保留。

IP_Flow模块引用限制与旧版工具参数弃用提示不等于缺失模块；完整工程仍必须满足无黑盒、无锁存器、通过实现及真实下载功能测试的独立检查。以上说明不把普通工具提示提升为未完成的真实PHY或射频验收。
'''
 (ROOT/'docs/CM_TOOL_WARNINGS.md').write_text(text,encoding='utf-8')
 print('SLE_TOOL_WARNING_REVIEW_PASS',result['counts'])
 return result
if __name__=='__main__':main()
