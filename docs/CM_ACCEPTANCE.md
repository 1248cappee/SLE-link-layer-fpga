# SLE CM架构与P101数字板测验收

范围：CM架构参考下的新SLE公共模块，P101 xc7z100ffg900-2，20MHz，数字接口测试器。
真实PHY、射频、独立低速晶振及功耗测量均不属于本次验收。

本次要求的CM功能验收：**PASS**。源码与镜像以 `build/board/manifest.json` 为准。

原含30分钟压力的完整验收：未通过全部条件。压力状态：USER_EXCLUDED。

用户已要求停止压力测试，本次未重启；这项排除不作为压力通过证明。

CM映射95项，原BLE对应43项；当前全部仿真和实现证据一致：True。板测三轮：True, True, True；30分钟压力：False。

setup余量 20.997ns，hold余量 0.043ns。镜像SHA256：`827173e6b9bb1ca6fac9ed1540a12e894bc8b9f4ba84b46df34e7c1f72c5314b`。

- CM架构映射与本轮SLE功能实现完成：PASS。
- 仿真回归通过：PASS。
- P101完整板级实现通过：PASS。
- 基础与CM功能板测通过：PASS。
- 接口测试器闭环及休眠循环（不含长压力）通过：PASS。
- 原含30分钟压力的组合验收通过：尚未完成。

每轮执行完整资源合同和CM场景，包含128KiB EM、四模式、长度边界、安全/取消/溢出恢复、五种调度粒度、499/500/501提交，以及10,000次休眠。每次休眠均检查实际主时钟计数停止/恢复、时间单调及EM保留。CRC/AES-MIC/SM4-MIC失败后的下一任务使用保留状态执行，邮箱ACK计数必须达到2，避免用复位代替恢复。

保留的压力程序设计门槛为不少于36,000,000,000个20MHz时钟，重复执行安全四模式、取消、共存撤销和休眠；本次是否执行及通过以开头的pressure_status为准。TX逐字节与电脑独立库预装的密文比较；RX逐轮检查MIC/交付和数据；每轮检查事件顺序。重复帧是相同公开测试向量，不宣称生产环境新消息可复用Nonce。

功能证据：`build/test_results.json`、`build/board/board_results.json`、`build/board/rounds/1..3/`及每场景ILA CSV。若重新授权并执行长压力，其结果单列`build/board/board_pressure.json`。先前被用户停止的r3压力资料保存在`build/board/history/r3_user_stopped_pressure/`，不作为当前镜像通过证明。重现入口为 `tools/sim.ps1`、`board/tools/build.ps1`、`board/tools/accept_cm.ps1 -SkipPressure`。

时隙/天数Nonce当前用于单帧TX或RX；链式、连续和双向安全活动使用载荷计数配置，硬件拒绝可能重复Nonce的组合。HMAC-SM3、配对和密钥派生未实现。低速参考由板内产生并由AON相位校正，结果不代表独立晶振精度或整机低功耗达标。

DRC、CDC、时序完整性及方法学原始报告均保留。下载前脚本拒绝自有逻辑组合驱动异步复位的报告；调试IP内部的剩余建议须结合原报告解释，不作形式化可靠性签核。默认只进行易失性FPGA下载，未写入QSPI。

剩余每一条DRC/方法学告警及影响判断见CM_TOOL_WARNINGS.md，结构化内容见build/board/warning_assessments.json。故障修复经过见CM_BOARD_ISSUES.md。
