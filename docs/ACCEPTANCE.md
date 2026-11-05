# 验收与证据边界

更新说明：以下18项模型测试及旧OOC数值保留为上一版历史记录。新增板测工程修改了 BRAM 复位控制并增加只读观测端口，不能继续将旧 OOC 源哈希视为当前版本。当前完整22项仿真、板级实现和实际下载测试见 [BOARD_ACCEPTANCE.md](BOARD_ACCEPTANCE.md) 及对应源哈希；真实 PHY 与射频仍独立验收。

本报告由 tools/audit.py 根据日志和源码哈希生成。输入资料及固定PHY的153个文件完整性通过。43个RW原模块全部有同目录/同文件名/同模块名对应，完整自有RTL58个文件。

## 链路层合同模型

18个XSim测试平台通过：tb_primitives, tb_crypto, tb_stream_crypto, tb_time_fifo, tb_registers, tb_control, tb_low_power, tb_bus, tb_auxiliary, tb_system, tb_scheduler, tb_recovery, tb_lengths, tb_secure_system, tb_appendix_f, tb_secure_chain, tb_resources, tb_submit_threshold。build/test_results.json保存全部被测源哈希；原始日志在build同名文件。测试覆盖附录F完整AES/SM4示例、独立库CCM向量、长包/反压、原对象边界、四种模式、16项竞争、取消/恢复、FIFO溢出、CRC/MIC/重复失败和独立安全链计数。

这些是定向仿真证据，不是全部状态空间的形式证明。requirements_coverage.json列出原表工作表/行号、实现和用例；目录地址读写验证不能替代所有业务组合覆盖。尚未穷举全部保留位、每个角色组合、取消同拍竞争、各信道/MCS组合及39位计数耗尽。共享EM冻结、屏障、回调和T−8准备属于明确的软件合同。

## 综合及OOC

状态：**PASS**。顶层rw_ble_top，器件xc7z100ffg900-2，20MHz，输入/输出延时5ns。自有链路层的setup slack：22.338ns；hold slack：0.081ns；LUT：34818；寄存器：31028；RAMB36：32；DSP：2。黑盒/锁存器检查见build/result.json及综合日志。

只有状态PASS且源哈希新鲜时，以上数值才归属于当前工程。OOC默认不包括外部PHY、PS/AXI系统、真实I/O引脚和板级时钟。异步复位路径为false path；其余数据路径使用50ns时钟、5ns端口约束。OOC报告有未定义板级clock-buffer位置/端口部分布线的警告；未进行板级CDC/复位释放及物理I/O签核。

DRC尚有31条Warning，包含RAMB36控制寄存器异步复位检查（报告20条达到规则显示上限）、DSP流水建议、无负载端口及缺少PS7。时序PASS并不代表这些告警已全部关闭。软复位先等待EM空闲再清ET/复位；硬复位后软件必须重新初始化引用对象。板级复位实现仍需检查BRAM控制信号的同步性及复位释放，不得把当前OOC当作板级硬件签核。

## 真实PHY与射频

原始PHY控制字段基线：Type1/2/3/4均通过。新MAC控制字段合同模式：Type1/2通过，Type3/4失败，详见PHY-06。两种模式都使用新同名弹性数据封装和固定版本真实TX/RX算法，测试只覆盖原始自环向量；不代表2047B各帧型/MCS矩阵通过。

完整调度+真实PHY：**受PHY-01/02/03/06阻塞，未通过验收**。真实同步时间、停稳和空口起止没有用常量或延时替代。射频上板：**未测试**。ModelSim未作为本次通过依据。

## 未宣称实现的功能

软件协商、资源分配、密钥派生和ARQ策略不编写C程序。辅助过滤/CMAC解析通过显式接口提供，尚未自动绑定任意业务PDU解析；HMAC-SM3、多于16B的CMAC及其他频段没有宣告支持。系统槽号/天数nonce profile尚未自动实现，需要新增接口/配置后另行验证。因而当前交付是可综合、可复现测试的链路层合同实现，不能标记为全部SLE规范业务认证通过。
