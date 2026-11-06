# 本轮实现告警逐项说明

镜像SHA256：`827173e6b9bb1ca6fac9ed1540a12e894bc8b9f4ba84b46df34e7c1f72c5314b`。以下条目未屏蔽、未降级；原始报告保留。原先自有BRAM异步控制问题已通过同步地址/写控制修复，BRAM内容不整块复位。

- **RTSTAT-10#1 (Warning)**：`board_i/jtag/inst/jtag_axi_engine_u/rd_cmd_fifo_i/inst_fifo_gen/gconvfifo.rf/grf.rf/gntv_or_sync_fifo.gl0.rd/gr1.gr1_int.rfwft/aempty_fwft_i`。JTAG/XSDBM中的未使用控制/FIFO标志没有可路由负载，属于未消费的调试输出；没有自有链路层有效数据路径。 原文见 `build/board/drc.rpt`。

- **REQP-165#1 (Advisory)**：`board_i/jtag/inst/jtag_axi_engine_u/rx_fifo_i/inst_fifo_gen/gconvfifo.rf/grf.rf/gntv_or_sync_fifo.mem/gbm.gbmg.gbmga.ngecc.bmg/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_noinit.ram/DEVICE_7SERIES.NO_BMM_INFO.SDP.WIDE_PRIM18.ram)`。JTAG AXI FIFO使用WRITE_FIRST。读写地址由原厂FIFO指针控制，测试RTL不能驱动内部RAM地址；保留原厂模式，通过完整主机读写和多轮功能测试检查本次使用，不将其描述为形式化碰撞证明或已通过被取消的长压力测试。 原文见 `build/board/drc.rpt`。

- **REQP-181#1 (Advisory)**：`board_i/jtag/inst/jtag_axi_engine_u/rd_cmd_fifo_i/inst_fifo_gen/gconvfifo.rf/grf.rf/gntv_or_sync_fifo.mem/gbm.gbmg.gbmga.ngecc.bmg/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_noinit.ram/DEVICE_7SERIES.NO_BMM_INFO.SDP.WIDE_PRIM36_NO_ECC.ram)`。JTAG AXI命令FIFO使用WRITE_FIRST，处理与REQP-165相同；该项不是此前自有BRAM异步控制告警。 原文见 `build/board/drc.rpt`。

- **REQP-181#2 (Advisory)**：`board_i/jtag/inst/jtag_axi_engine_u/wr_cmd_fifo_i/inst_fifo_gen/gconvfifo.rf/grf.rf/gntv_or_sync_fifo.mem/gbm.gbmg.gbmga.ngecc.bmg/inst_blk_mem_gen/gnbram.gnativebmg.native_blk_mem_gen/valid.cstr/ramloop[0].ram.r/prim_noinit.ram/DEVICE_7SERIES.NO_BMM_INFO.SDP.WIDE_PRIM36_NO_ECC.ram)`。JTAG AXI命令FIFO使用WRITE_FIRST，处理与REQP-165相同；该项不是此前自有BRAM异步控制告警。 原文见 `build/board/drc.rpt`。

- **LUTAR-1#1 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD6_RD/U_RD_FIFO/SUBCORE_FIFO.xsdbm_v3_0_0_rdfifo_inst/inst_fifo_gen/gconvfifo.rf/grf.rf/rstblk/ngwrdrst.grst.g7serrst.gwrrd_rst_sync_stage[2].rrst_inst/ngwrdrst.grst.g7serrst.rd_rst_reg[2]_i_1`。Vivado生成的XSDBM读/写FIFO内部复位路径。属于调试IP，未通过屏蔽规则处理；自有RTL已经改为寄存器输出复位。此项仍有工具提示的毛刺风险，本轮数字测试只能提供功能证据，不能替代器件级可靠性签核。 原文见 `build/board/methodology.rpt`。

- **LUTAR-1#2 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD6_RD/U_RD_FIFO/SUBCORE_FIFO.xsdbm_v3_0_0_rdfifo_inst/inst_fifo_gen/gconvfifo.rf/grf.rf/rstblk/ngwrdrst.grst.g7serrst.gwrrd_rst_sync_stage[2].wrst_inst/ngwrdrst.grst.g7serrst.wr_rst_reg[2]_i_1`。Vivado生成的XSDBM读/写FIFO内部复位路径。属于调试IP，未通过屏蔽规则处理；自有RTL已经改为寄存器输出复位。此项仍有工具提示的毛刺风险，本轮数字测试只能提供功能证据，不能替代器件级可靠性签核。 原文见 `build/board/methodology.rpt`。

- **LUTAR-1#3 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD6_WR/U_WR_FIFO/SUBCORE_FIFO.xsdbm_v3_0_0_wrfifo_inst/inst_fifo_gen/gconvfifo.rf/grf.rf/rstblk/ngwrdrst.grst.g7serrst.gwrrd_rst_sync_stage[2].rrst_inst/ngwrdrst.grst.g7serrst.rd_rst_reg[2]_i_1`。Vivado生成的XSDBM读/写FIFO内部复位路径。属于调试IP，未通过屏蔽规则处理；自有RTL已经改为寄存器输出复位。此项仍有工具提示的毛刺风险，本轮数字测试只能提供功能证据，不能替代器件级可靠性签核。 原文见 `build/board/methodology.rpt`。

- **LUTAR-1#4 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD6_WR/U_WR_FIFO/SUBCORE_FIFO.xsdbm_v3_0_0_wrfifo_inst/inst_fifo_gen/gconvfifo.rf/grf.rf/rstblk/ngwrdrst.grst.g7serrst.gwrrd_rst_sync_stage[2].wrst_inst/ngwrdrst.grst.g7serrst.wr_rst_reg[2]_i_1`。Vivado生成的XSDBM读/写FIFO内部复位路径。属于调试IP，未通过屏蔽规则处理；自有RTL已经改为寄存器输出复位。此项仍有工具提示的毛刺风险，本轮数字测试只能提供功能证据，不能替代器件级可靠性签核。 原文见 `build/board/methodology.rpt`。

- **PDRC-190#1 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD2/stat_reg_reg[0]`。XSDBM状态同步链未放在同一SLICE，可能影响亚稳态裕量。保留原厂调试IP实现与约束，结合CDC安全分类、实际JTAG/ILA多轮测试判断本轮用途；不宣称完成MTBF签核。 原文见 `build/board/methodology.rpt`。

- **PDRC-190#2 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD2/stat_reg_reg[1]`。XSDBM状态同步链未放在同一SLICE，可能影响亚稳态裕量。保留原厂调试IP实现与约束，结合CDC安全分类、实际JTAG/ILA多轮测试判断本轮用途；不宣称完成MTBF签核。 原文见 `build/board/methodology.rpt`。

- **PDRC-190#3 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD2/stat_reg_reg[2]`。XSDBM状态同步链未放在同一SLICE，可能影响亚稳态裕量。保留原厂调试IP实现与约束，结合CDC安全分类、实际JTAG/ILA多轮测试判断本轮用途；不宣称完成MTBF签核。 原文见 `build/board/methodology.rpt`。

- **PDRC-190#4 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD2/stat_reg_reg[3]`。XSDBM状态同步链未放在同一SLICE，可能影响亚稳态裕量。保留原厂调试IP实现与约束，结合CDC安全分类、实际JTAG/ILA多轮测试判断本轮用途；不宣称完成MTBF签核。 原文见 `build/board/methodology.rpt`。

- **PDRC-190#5 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD3/stat_reg_reg[0]`。XSDBM状态同步链未放在同一SLICE，可能影响亚稳态裕量。保留原厂调试IP实现与约束，结合CDC安全分类、实际JTAG/ILA多轮测试判断本轮用途；不宣称完成MTBF签核。 原文见 `build/board/methodology.rpt`。

- **PDRC-190#6 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD3/stat_reg_reg[1]`。XSDBM状态同步链未放在同一SLICE，可能影响亚稳态裕量。保留原厂调试IP实现与约束，结合CDC安全分类、实际JTAG/ILA多轮测试判断本轮用途；不宣称完成MTBF签核。 原文见 `build/board/methodology.rpt`。

- **PDRC-190#7 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD3/stat_reg_reg[2]`。XSDBM状态同步链未放在同一SLICE，可能影响亚稳态裕量。保留原厂调试IP实现与约束，结合CDC安全分类、实际JTAG/ILA多轮测试判断本轮用途；不宣称完成MTBF签核。 原文见 `build/board/methodology.rpt`。

- **PDRC-190#8 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD3/stat_reg_reg[3]`。XSDBM状态同步链未放在同一SLICE，可能影响亚稳态裕量。保留原厂调试IP实现与约束，结合CDC安全分类、实际JTAG/ILA多轮测试判断本轮用途；不宣称完成MTBF签核。 原文见 `build/board/methodology.rpt`。

- **PDRC-190#9 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD7_STAT/stat_reg_reg[0]`。XSDBM状态同步链未放在同一SLICE，可能影响亚稳态裕量。保留原厂调试IP实现与约束，结合CDC安全分类、实际JTAG/ILA多轮测试判断本轮用途；不宣称完成MTBF签核。 原文见 `build/board/methodology.rpt`。

- **PDRC-190#10 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD7_STAT/stat_reg_reg[1]`。XSDBM状态同步链未放在同一SLICE，可能影响亚稳态裕量。保留原厂调试IP实现与约束，结合CDC安全分类、实际JTAG/ILA多轮测试判断本轮用途；不宣称完成MTBF签核。 原文见 `build/board/methodology.rpt`。

- **PDRC-190#11 (Warning)**：`dbg_hub/inst/BSCANID.u_xsdbm_id/CORE_XSDB.UUT_MASTER/U_ICON_INTERFACE/U_CMD7_STAT/stat_reg_reg[2]`。XSDBM状态同步链未放在同一SLICE，可能影响亚稳态裕量。保留原厂调试IP实现与约束，结合CDC安全分类、实际JTAG/ILA多轮测试判断本轮用途；不宣称完成MTBF签核。 原文见 `build/board/methodology.rpt`。

## 综合阶段的其他提示

Vivado 2020.2将显式SIM_DEVICE=7SERIES的BUFGCE展开为BUFGCTRL时，仍可能提示展开后原语的默认SIM_DEVICE值并自动改成7SERIES。该提示不作为属性已经正确的证明；后实现check_debug_clocks.tcl要求真实门控原语SIM_DEVICE=7SERIES、专用同步CE配置以及JTAG/ILA常开时钟连接，并保存debug_clocks.rpt。未屏蔽此工具消息。

Synth 8-589是四态兼容写法===在硬件中转为二态比较：实际输入由已连接寄存器或有效接口驱动，硬件不依赖X值判决。Synth 8-7129保留CS固定布局后出现未使用端口/位提示；未用位没有挪用为新业务字段。Synth 8-6841是大深度字节写RAM的分解性能建议，地址范围与所有字节通道仍由仿真及完整EM板测验证。当前CCM私有RAM另有定向BRAM及REQP-1839/1840零违规证据，不再使用LUTRAM回退。原始综合日志随implementation_logs保留。

IP_Flow模块引用限制与旧版工具参数弃用提示不等于缺失模块；完整工程仍必须满足无黑盒、无锁存器、通过实现及真实下载功能测试的独立检查。以上说明不把普通工具提示提升为未完成的真实PHY或射频验收。
