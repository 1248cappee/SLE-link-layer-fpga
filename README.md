# SLE公共模块与P101数字板测工程

CM.zip仅作架构参考。当前构建包含90个核心RTL及6个板测RTL。CM接口及能力边界见 [CM接口](docs/CM_INTERFACE.md)，95项职责对应见 [CM映射](docs/cm_mapping.json)。本轮使用28项XSim测试和87个板测同源场景；实际验收以 [CM验收报告](docs/CM_ACCEPTANCE.md) 及源码/镜像哈希为准。旧18/22项仿真、44场景及旧OOC报告为历史资料。

目标为 `xc7z100ffg900-2`、20MHz、Vivado/XSim 2020.2。原43个BLE文件保持对应，CM的95项全部映射：36项同名实现、3项复用对应的AES正向变换，56项按选定配置排除。原CM RTL不进入filelist。三份资源表原定义地址及ET/CS/描述符步长保持兼容，CM扩展ABI为1.1。

本轮提供五种调度粒度、实际主时钟停钟及时间交接、常开主机访问、诊断、中断、共存和AES/SM4数据面。板测使用可综合接口测试器；PHY、射频及ARM C不参与本轮数字验收。

从项目根目录运行：

```powershell
& SLE/tools/sim.ps1
& SLE/tools/check_cm_crypto_bram.ps1
& SLE/board/tools/build.ps1
& SLE/tools/accept_cm.ps1 -SkipPressure
$py='C:\Users\kong\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& $py -X utf8 SLE/tools/package_board.py --skip-pressure
```

用户已取消长压力测试；以上入口明确排除该项，执行三轮PS初始化、易失性下载及87场景。每轮包含10,000次休眠及全128KiB EM保留校验。下载顺序固定为PS初始化→FPGA下载→PS后配置。只在唯一P101目标上执行，不写QSPI。只有重新授权长压力测试后才使用不带SkipPressure的完整入口；功能通过不代表30分钟压力通过。

- [板级操作与地址](board/README.md)、[CM寄存器和安全合同](docs/CM_INTERFACE.md)、[原业务接口](docs/INTERFACE.md)。
- [CM验收报告](docs/CM_ACCEPTANCE.md)、[逐项工具告警](docs/CM_TOOL_WARNINGS.md)、[板测问题闭环](docs/CM_BOARD_ISSUES.md)。
- [RTL清单](rtl.f)、[板级清单](board.f)、[43项原模块对应](docs/module_mapping.json)、[95项CM对应](docs/cm_mapping.json)。
- `build/test_results.json`、`build/board/manifest.json`、`build/board/rounds/1..3/`保存本轮日志与哈希。排除压力后的功能交付为 `build/SLE_CM_P101_NO_PHY_FUNCTIONAL.zip`；`VERIFIED.zip`仍要求原完整验收，包括30分钟压力。两种包均拒绝源码、镜像和板测证据不一致。

可用 `tools/verify_regeneration.py` 在隔离副本验证生成流程；结果保存在 `build/regeneration_audit.json`。原22仿真/44板测的源码和结果保存在 `build/baselines/pre_cm_20261106/`。拆分密码模块前的r3源码和实际板测证据另存于 `build/baselines/cm_r3_before_cipher_split_20261106/`，不能替代新RTL验收。

能力边界：时隙/天数Nonce用于单帧TX或RX；链式、连续和双向安全活动使用载荷计数Nonce。HMAC-SM3、配对及密钥派生未实现。低速参考由板内产生并由常开相位校正，不能据此认定独立晶振精度、整机休眠功耗、真实PHY或射频通过。PHY问题继续保留在 [PHY_ISSUES.md](docs/PHY_ISSUES.md)。

<details>
<summary>历史BLE架构移植说明（以下数值、命令和能力边界不是本轮CM验收）</summary>

# SLE 链路层 FPGA 工程

目标：P101 `xc7z100ffg900-2`、20 MHz。RTL 使用 Verilog-2001；测试平台使用 SystemVerilog。工程按 BLE.zip 的 10 个目录、43 个原文件/模块建立对应实现，另补公共依赖。六份输入资料保留在上级目录，未修改。

当前验收分层记录在 [验收报告](docs/ACCEPTANCE.md)。链路层合同模型、真实 PHY 边界回归、射频上板分别验收。**现有 PHY 缺少真实空口起止、同步时间和停稳信号，完整真实 PHY 调度联调尚不能通过验收。** 不要把模型的信号常量接到实际系统。

新增 [不接 PHY 的 P101 数字板测工程](board/README.md)：JTAG-to-AXI、独立测试窗口、可综合接口测试器、序列控制器和 ILA。原有18项加新增4项共22项仿真；板级场景与真实 JTAG 使用同一套44场景输入。最新板级验收单独记录在 [板测报告](docs/BOARD_ACCEPTANCE.md)。

## 工程入口

- [完整文件清单](rtl.f)：58 个自有 RTL 文件，顶层 `rw_ble_top`。
- [43 个模块对应清单](docs/module_allocation.json)：原文件和新 RTL 文件、模块名及原文件哈希。完整端口变化清单由本地原始资料生成。
- [接口合同](docs/INTERFACE.md)：主机、内存、扩展业务对象、软件交接和 PHY 时序。
- [参数与编码清单](docs/PARAMETERS.md)：时间单位、计数方向、位宽、指针、长度和协议编码。
- [输入文件哈希](docs/source_manifest.json)，用于核对本地参考资料版本。

原 CRC、白化和 FEC 位置为同名带反压的数据接口封装；算法由 `external/p101_phy_rf` 中固定版本 PHY 提供。43 个名称对应不意味着沿用原 BLE 端口 ABI；模块职责可查阅各目录说明，新端口及其变化在本地生成的完整清单中逐项说明。广播、发现、接入、G/T 等模块执行角色窗口策略，协商、业务编排及重传策略由软件提供。

公开仓库只包含本工程 RTL、测试、脚本和说明。`external/p101_phy_rf/` 来自独立私有仓库，没有随本仓库公开；原始 PDF、表格、BLE.zip，以及从这些材料中完整提取的表格、端口清单和 PHY 问题明细也不包含在公开仓库。`build/` 中的仿真日志、报告及设计检查点是本地生成物。要重现基于原始资料的报告，需要有相应资料和私有 PHY 的访问权限，并在本地按下面说明生成依赖。

## 一键验证

在本目录打开 PowerShell，使用本机运行时：

```powershell
$py='C:\Users\kong\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
& .\tools\sim.ps1 -Python $py
& $py -X utf8 tools/run_real_phy.py --native-control
& $py -X utf8 tools/run_real_phy.py
& .\tools\synth.ps1 -StageRoot D:\codex_test\sle-1105-release
& $py -X utf8 tools/package.py
& $py -X utf8 tools/audit.py
```

`run_real_phy.py` 的合同控制字段回归会保留 Type3/4 的已知失败并返回非零；原始 PHY 控制字段模式单独记录，不替代合同模式。测试要求日志出现专用 PASS 标志，同时没有 Fatal/ERROR。源文件哈希随报告保存，防止引用旧结果。

链路层模型仿真只依赖本仓库的 RTL、测试文件及本机 Vivado。真实 PHY 回归需要先运行 `tools/vendor_phy.py` 获取锁定版本，调用者须有私有仓库权限；完整资源提取和审计需要将原始 PDF、表格和 BLE.zip 放在本工程的上一级目录，再运行 `tools/bootstrap.py` 和 `tools/package.py`。生成的原始内容仍由 `.gitignore` 排除，避免意外上传。

Vivado 2020.2 安装路径为 `D:\vivado\Vivado\2020.2`。本机由 Python 启动 Vivado 曾出现临时 Tcl 路径异常，可用 `tools/synth.ps1` 在 ASCII 暂存目录直接启动；这不会变更 RTL 或放宽时序约束。默认只综合自有链路层，不将外部 PHY 算法计入本次资源。

重新生成集成层：先运行 `tools/generate_boundaries.py`，再运行 `tools/integrate.py`、`tools/gen_tb_ports.py`、`tools/package.py`。业务执行代码在 packet controller/common RTL；生成器管理角色和数据接口封装、显式层级连线。勿直接修改这些生成文件后再运行生成器。

## 当前实现范围

实现表中定义的调度寄存器、原对象布局、四种模式、描述符链、取消/恢复、共享 BRAM、事件队列，以及 AES/SM4 CCM 数据面和辅助过滤/CMAC 解析接口。2.4GHz 的 76 个数据信道及 3 个扫描信道有明确支持；其他频段、HMAC-SM3、任意长度 CMAC、密钥协商、软件 ARQ/资源分配不由本工程隐式实现。低功耗保时模块可独立使用，默认顶层不关闭工作时钟。

安全 profile 使用外部软件提供的会话密钥、IV、TX/RX 初始包计数及方向；链内 TX 和成功交付的 RX 分别推进计数，39 位耗尽后拒绝继续复用。广播类使用系统槽号/天数的其他 nonce profile 尚未加入自动生成，不能据此宣称全部安全业务配置通过。所有未验收项目见验收报告。

</details>
