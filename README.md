# SLE 链路层 FPGA 工程

目标：P101 `xc7z100ffg900-2`、20 MHz。RTL 使用 Verilog-2001；测试平台使用 SystemVerilog。工程按 BLE.zip 的 10 个目录、43 个原文件/模块建立对应实现，另补公共依赖。六份输入资料保留在上级目录，未修改。

当前验收分层记录在 [验收报告](docs/ACCEPTANCE.md)。链路层合同模型、真实 PHY 边界回归、射频上板分别验收。**现有 PHY 缺少真实空口起止、同步时间和停稳信号，完整真实 PHY 调度联调尚不能通过验收。** 不要把模型的信号常量接到实际系统。

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
