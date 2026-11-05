# P101 链路层数字自测工程

目标：`xc7z100ffg900-2`，Vivado 2020.2，20MHz。本工程使用可综合的数字 PHY 接口测试器，结果不代表 PHY 或射频验收。

## 构建与实际运行

在项目根目录 PowerShell 执行：

```powershell
& SLE/tools/sim.ps1
& SLE/board/tools/build.ps1
& SLE/board/tools/run.ps1
```

脚本需要本机已安装的 Vivado/Vitis 2020.2。`build.ps1` 在短英文临时路径构建；产物及报告收集到 `SLE/build/board/`。Windows 受限环境可能阻止 Vivado 子任务、WMI 或 cs_server 运行库提取，应在具有相应本机权限的终端执行。无需安装新工具。

构建脚本同时运行实际生成的 `proc_sys_reset` IP 混合语言仿真，检查 PS/辅助/失锁/调试复位及释放。辅助输入是低有效，固定接1；构建时检查该极性。已下载同一镜像、PS时钟保持且仅需重复测试时，可使用 `run.ps1 -TestsOnly`。

`run.ps1` 验证当前 RTL、构建脚本、运行脚本及镜像哈希，要求 JTAG 链中仅有一个目标且只有一个 xc7z100，先复位/停止 ARM 并初始化 PS，再下载易失性 FPGA 镜像、执行 PS post_config、配置 ILA 并执行测试。PS 系统复位可能清除 PL 配置，必须放在 FPGA 下载之前。此操作会替换当前 PL 配置并重置 PS，不写 QSPI。

PS 配置来自本机物理组提供的 P101 `member567_system.tcl`（源文件 SHA256：`1445ce5df9545237e51acedf8e14f00584104af7d9f10d76a723b3aa37754b9c`）；仅复用 PS 配置，关闭 PS AXI 主机和 SPI0，不引入 AD9361、PHY 或 RF 引脚。使用 PS FCLK0=100MHz、Clock Wizard No_buffer 输入及 20MHz 输出。PS 固定引脚/DDR 由 PS7 IP 导出；DDR 不承载本次链路层测试数据。

## 主机地址与测试窗口

本地字节地址加 `0x40000000` 后为 JTAG AXI 地址。原链路层寄存器 `0x00000..0x00fff`、EM `0x20000..0x3ffff` 保持原布局。独立测试窗口如下：

- `0x40000`：RO `0x534c4254`，数字测试镜像 ID；`0x40004`：ABI `0x00010000`。
- `0x40008`：RO 状态，bit0 序列忙、bit1 完成、bit2 失败、bit3 LL 忙、bit6 TX 停稳、bit7 RX 排空。
- `0x4000c`：RW 场景编号；`0x40010`：RW bit0 测试器使能，复位关闭，仅空闲允许改变。
- `0x40014`：W1P bit0 启动序列、bit1 请求中止、bit2 链路层和测试器硬复位。中止在当前总线访问完成后释放所有权；硬复位要求序列空闲。
- `0x40018`：RO `[9:0]` 首个失败/当前 PC，`[17:10]` 失败原因；`0x4001c/20`：实际值/预期值。
- `0x40024/28`：RO 实时粗/细时间（独立读取不构成原子快照）；`0x4002c/30`：LL 错误/FIFO 项数。原子时间读取仍使用原 SNAP 合同。
- `0x40040/44/48/4c`：RW RX wire 字节数、CRC通过/重复位、读延迟拍数（最小2）、模拟 TX 持续拍数（最小1）。
- `0x40050/54/58`：RW RX 同步/邮箱产生延迟拍数、TX 反压掩码。配置只允许 LL 和序列空闲时写。
- `0x4005c/60/64/68/6c`：RO TX 字节数、测试器协议错误、实际邮箱释放次数、TX 包数、RX 包数。
- `0x44000..0x47fff`：WO 1024 条、每条16B的序列 RAM；`0x48000..0x487ff`：RO TX 捕获；`0x49000..0x497ff`：RW RX 预装数据。

缓冲和指令装载需等待 LL/序列空闲；自动测试期间普通 LL 主机访问返回总线错误，独立测试状态仍可读取。原 EM READY 后对象冻结仍由主机遵守。缓冲初始化不得与包处理并发。指令 RAM 具有注册装载级，最后一笔装载完成后再发 START。

## 序列格式与故障

四个32位小端字为：`op/be/expected_error`、本地地址、数值、掩码。字0 `[7:0]` 操作码，`[11:8]` 字节使能，bit16 表示预期 LL 总线错误。

- 0 END；1 WRITE；2 CHECK；3 WAIT（字2为周期数）；4 POLL（按字3掩码比较）。
- 5 等待绝对时间（字2粗时间、字3细时间）。
- 6 相对时间发布 ET；7 只准备时间；9 使用已保存目标时间发布另一 ET。字1为 ET 本地总线地址，字2为相对槽数（6/7），字3低16位为优先级/模式，`[25:16]` 为目标 fine。
- 8 在指定提前 fine 数发布前一个 ET：字2为提前量。只用于本工程空闲 XBAR/EM 路径；仿真通过真实调度器提交时间检查 499/500/501，禁止将该延迟假设推广到其他总线实现。
- 10/11 对连续 EM 做地址异或图样填充/校验，字1为起始本地地址，字2为种子，字3为 word 数（1..32768）；范围必须处于 EM。

失败原因：1非法指令、2总线错误不符、3数据不符、4看门狗、5中止、6指令越界、7块操作范围非法。看门狗为67,108,864拍（约3.36秒），POLL 无进展会失败；外部脚本也有超时。块校验首个错误地址可由 `expected XOR seed` 还原。

硬复位清控制状态，不清 BRAM。复位采样边沿允许此前已接受的 RAM 写入提交，旧 ACK 被清除；复位后必须重新初始化 ET/描述符等所有权对象，不能假设未收到 ACK 就未写入。软复位继续遵循等待包边界、邮箱排空及 EM 完成的原合同。

## 测试证据

`tools/cases.py` 产生44个同源场景，`cases/suite.tcl` 用于 JTAG，`verification/board_vectors.mem` 用于 `tb_board_suite`。测试由软件比较实际字节、描述符和事件，不仅查看 PASS 位。密码学期望来自现有独立 AES/SM4 参考向量。

真实执行生成 `board_results.json`、`board_test.log`、每场景 ILA CSV 和16项竞争的原始事件日志。ILA trace 从低位起：0 LL error、1 LL wait、2 LL req、3 host req、4 TX error、5 TX quiescent、6 RX drain、7 RX stop、8 RX sync、9 RX IRQ、10 RX rvalid、11 RX write、12 RX req、13 TX stop、14 TX done、15 TX started、16 TX prepared、17 TX launch、18 TX last、19 TX ready、20 TX valid、21 cfg ready、22 cfg valid、23 IRQ、24 LL busy、25 sequence failed、26 done、27 busy；`[35:28]` reason、`[45:36]` PC、`[77:46]` 模型错误、`[85:78]` FIFO计数、`[90:86]` LL错误、`[162:91]` 队首、`[172:163]` fine、`[202:173]` slot、`[234:203]` 场景ID，其余为0。

验收必须分别记录仿真、完整实现、基础板测和接口测试器闭环板测。无线协议过程的完整实现、真实 PHY 和空口时序仍需后续独立验收。
