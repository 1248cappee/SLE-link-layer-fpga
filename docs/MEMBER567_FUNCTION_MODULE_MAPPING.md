# 成员5 6 7功能代码及CM公共模块分工

版本：v2.0  
更新日期：2026年11月6日  
适用工程：`D:/星闪项目/1105-project/SLE`  
更新依据：本轮CM架构改写与P101数字功能验收已完成。

本文件给出建议的后续维护主责、汇报范围及接口协作，并不据此推断每一项历史工作的实际作者。原43个BLE模块的文件和层级对应保留；公共模块按CM参考职责重新实现，原CM RTL没有加入构建。

## 1 更新后的分工结论

- **成员5：收发执行、安全数据面、PHY适配与系统集成。** 负责把任务执行成数据搬运和收发事实，并维护AES/SM4、CCM及对应异常恢复。
- **成员6：时间、任务调度、跳频、共存与低功耗时间管理。** 负责调度合法性、任务派发、ET状态，以及实际停钟、唤醒和时间恢复。
- **成员7：软件接口、共享内存、寄存器、中断诊断与资源交接合同。** 负责主机访问和结果公开，保证发布、访问、消费、重用的顺序。

**CM公共模块应按功能并入三个人的职责，不另设一个全部归某人的CM包。** 综合、布局布线、bitstream和三轮板测是系统共同成果；成员5牵头集成与执行，成员6、7分别对自己的功能证据负责。

## 2 本轮CM成果具体加到哪里

| 已实现或已验收内容 | 主要归属 | 其他成员配合 |
| --- | --- | --- |
| AES七个模块的控制、轮运算、密钥及变换层级 | 成员5 | 成员7审核密钥/命令配置与冻结接口 |
| 原三个双向变换参考项共用新写的AES正向变换 | 成员5 | 映射登记说明适用范围，不增加三份重复算法 |
| SM4独立轮/密钥/执行层级，CCM和MIC | 成员5 | 成员6提供适用的时间/天数与代次；成员7提供配置接口 |
| CCM私有Payload BRAM、同步控制、读有效、复位/中止后恢复 | 成员5 | 成员7复核与共享EM的握手边界；它不是共享EM控制器 |
| 软件CCM DMA与安全数据搬运 | 成员5 | 成员6负责占用期间的调度暂停；成员7负责命令寄存器及EM合同 |
| PHY请求、结果及弹性响应缓冲 | 成员5 | 与冻结PHY合同对接；真实PHY缺失信号另行验收 |
| 125µs/0.5µs时间、定时器、校时及时间交接 | 成员6 | 成员7实现寄存器访问语义；成员5接入真实PHY时间事实 |
| 16项ET、五种调度粒度、499/500/501提交及仲裁 | 成员6 | 成员7提供READY发布与配置；成员5接收任务并执行 |
| 共存优先级、授权与包边界撤回 | 成员6 | 成员5执行停止/排空；成员7提供软件配置及状态 |
| 休眠准入、物理停钟、唤醒、时间单调与恢复 | 成员6 | 成员5保证包/安全/测试器停稳和调试时钟连接；成员7保证常开主机访问及EM保留 |
| AHB/XBAR、REG/EM分离事务、字节写、等待和错误 | 成员7 | 成员5完成顶层连接，成员6提供休眠期间的访问控制条件 |
| CM扩展寄存器、事件FIFO、中断、诊断统计与首错记录 | 成员7 | 成员5、6产生收发、执行、调度和唤醒事实 |
| 共享128KiB EM仲裁、读写ACK与复位边界 | 成员7 | 调度器和包执行器分别由成员6、5使用 |
| 公共同步器和复位基础模块 | 成员5维护基础实现 | 成员6复核时间/停钟跨域；成员7复核主机/EM响应边界 |
| 新镜像完整板级实现、三轮初始化/下载和87场景执行 | 三人共同成果，成员5牵头集成 | 成员6核验时间/调度/休眠；成员7核验总线/资源/事件 |

### 2.1 CM数量如何对应

| 主责 | 同名实现的CM原参考项 | 等效共用的CM原参考项 | 无一对一原模块的新增CM RTL | 当前CM目录实际RTL |
| --- | --- | --- | --- | --- |
| 成员5 | 20 | 3 | 5 | 25 |
| 成员6 | 8 | 0 | 1 | 9 |
| 成员7 | 8 | 0 | 1 | 9 |
| 合计 | 36 | 3 | 7 | 43 |

三个等效项共用已有正向变换实现，不另外计成三个RTL文件。95项原参考映射由36项同名实现、3项等效共用、56项按配置排除组成；不能写成“95项功能全部实现”。43个当前CM RTL包含7个新增文件。完整构建为90个核心RTL加6个板测RTL，共96个。

## 3 成员5 收发执行安全处理与集成

### 3.1 基础功能

1. 接收任务索引、模式、CS指针和目标时间，读取CS、描述符及扩展元数据。
2. 实现TX、RX、TX→RX、RX→TX、链式活动、窗口及包边界取消。
3. TX从EM取数，执行可选安全处理，完成PHY配置与32位流握手、反压和结果回写。
4. RX按头、长度、Payload和确认访问邮箱，等待rvalid；检查CRC、MIC、重复及窗口，写接收RAM并释放邮箱。
5. 完成包数据及描述符结果写回后产生收发事实，排空在途责任后向调度器返回执行状态。
6. 维护过滤/地址解析辅助接口、PHY封装、系统顶层、接口测试器及板上序列器。

### 3.2 本轮应新增到成员5汇报的工作

- 按CM参考职责拆分AES控制、轮数据通路、密钥扩展、S盒、行移位、列混合及顶层；明确三个原双向变换项的等效共用。
- 增加或维护独立SM4层级、CCM、4B MIC、流式安全发送与软件CCM DMA。
- 完成CCM私有BRAM的同步控制和显式读有效处理；验证待返回读期间复位、两种算法计算期间中止、RAM保留、无旧完成及独立向量恢复。
- 维护算法连续切换、密文逐字节比较、CRC/MIC失败后下一任务恢复的系统路径。
- 牵头完整板级集成、PS初始化/下载脚本、ILA连接、镜像/源码哈希和交付整理。

### 3.3 代码与RW原模块

| 功能 | 当前代码 | RW对应 |
| --- | --- | --- |
| 包执行、模式策略与EM访问适配 | `rw_ble_packet_cntl/verilog/rtl/`三个RTL | BLE同名packet controller三个模块 |
| PHY控制与响应缓冲 | `CM/rw_cm_radio_cntl/verilog/rtl/` | CM的`rw_cm_radio_cntl`、`rw_cm_jitter_elim_fifo` |
| AES七模块 | `CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_*.v` | CM同名AES模块；三个bidir变换参考项映射到正向变换 |
| CCM和安全引擎接口 | 同目录`rw_cm_ccm_top.v`、`rw_cm_crypto_engine.v` | CM同名模块 |
| SM4与软件DMA | 同目录`sle_cm_sm4_*.v`、`sle_cm_crypto_dma.v` | 新增，无一对一RW原模块 |
| 安全辅助 | `common/rtl/sle_block_cipher.v`、`sle_ccm_stream_tx.v`、`sle_cmac.v` | 新增，与CM安全路径协作 |
| 同步与复位 | `CM/rw_cm_misc/synchronization/`、`reset/` | 同步器对应CM同名模块；复位同步为新增 |
| 集成及PHY数据封装 | `rw_ble_top/`中四个集成/控制RTL、`rw_ble_bit_stream/`、`rw_ble_lr_fec_dec/` | BLE同名位置；低功耗顶层封装归成员6 |
| 测试器及板级连接 | `board/rtl/sle_phy_test.v`、`sle_board_sequence.v`、`sle_board_core.v`、`sle_board_axi.v` | 数字板测新增 |

白名单及地址解析仍由`rw_ble_list_search_engine`、`rw_ble_ral_search_engine`承接BLE同名位置，属于成员5辅助数据路径。PHY同名封装不等于重新实现CRC、白化、FEC或解调算法。

### 3.4 验证责任与汇报用语

重点维护`tb_cm_cipher`、`tb_crypto`、`tb_stream_crypto`、安全系统/链式测试、接收错误恢复和板级闭环。成员5对系统连通与证据归档牵头，不把全部28项测试或全部87场景写成个人独立成果。

可汇报为：**负责收发任务执行、安全数据面及系统集成，完成CM密码引擎层级改写、AES/SM4 CCM、私有BRAM和异常恢复，并牵头数字板测闭环。**

## 4 成员6 时间调度共存与低功耗

### 4.1 基础功能

1. 产生125µs粗时间和0.5µs细时间，处理30位回绕、三个定时器、校时和原子时间状态。
2. 调度16项ET，检查提前量及网格，按目标时间、优先级和ET索引仲裁；冲突不自动顺延。
3. 维护任务派发、ET所有权、ET状态回写及终态事件；终态消费后解除对应owned。
4. 提供角色模式与活动时间策略、扫描推进、跳频计算和共存授权/撤回。

### 4.2 本轮应新增到成员6汇报的工作

- 完成25/50/75/100/125µs五种调度网格及混合竞争，保持基础时基和最小500 fine提交门槛。
- 完成常开域与主时钟门控的休眠准入、唤醒和时间/相位/day恢复；核验7系列时钟门控配置。
- 对10,000次休眠/唤醒场景负责：检查实际主时钟计数停止和恢复、时间单调及与EM保留条件的配合。
- 提供安全使用的slot/day及时间generation，处理校时和耗尽边界；仅在适用单帧TX/RX配置下启用时间Nonce。
- 完成共存授权延迟、拒绝及撤回策略，并与成员5对齐包边界停止行为。

### 4.3 代码与RW原模块

| 功能 | 当前代码 | RW对应 |
| --- | --- | --- |
| 时间、休眠状态机及恢复 | `CM/rw_cm_timing_gen/verilog/rtl/`五个RTL | CM的timing_gen、fsm、lp、resync、coex |
| 活动调度和ET所有权 | `CM/rw_cm_activity_scheduler/verilog/rtl/rw_cm_activity_scheduler.v` | CM同名Activity Scheduler |
| 调度网格 | 同目录`sle_schedule_grid.v` | 新增，无一对一RW原模块 |
| 共存 | `CM/rw_cm_wlan_coex_cntl/`、`CM/rw_cm_coex_if/` | CM同名模块 |
| 角色、CS检查、活动计时和扫描 | `rw_ble_event_cntl/verilog/rtl/`17个RTL | BLE同名事件控制模块 |
| 跳频 | `rw_ble_freq_select/verilog/rtl/rw_ble_freq_select.v` | BLE同名模块 |
| 低功耗封装及板级门控 | `rw_ble_top/verilog/rtl/rw_ble_top_tglp_ext.v`、`board/rtl/sle_board_clock_gate.v` | 前者对应BLE原模块；后者新增 |

`rw_ble_event_cntl_em_manager`解析和检查CS，不是Buffer分配器。任务级时间策略归成员6，真实TX启动、RX同步接纳及到期后的排空动作由成员5执行。选频计算不包含SPI调谐AD9361。

### 4.4 验证责任与汇报用语

重点维护调度、提交临界、回绕、CM网格、day/generation、休眠及共存场景；与成员7共同检查休眠期间总线访问和EM保留。

可汇报为：**负责时间、任务调度、跳频、共存及低功耗控制，完成五种调度粒度、停钟唤醒和时间恢复，并验证多任务竞争及10,000次休眠/唤醒。**

## 5 成员7 软件接口共享内存与资源交接

### 5.1 基础功能

1. 维护AHB/XBAR和板级AXI桥，落实地址、字节使能、独立握手、等待及错误返回。
2. 维护RO/RW/W1C/W1P、复位值、非法命令、快照、扩展配置和owned写保护。
3. 维护128KiB共享EM、三客户端仲裁、同步读写与ACK/fault。
4. 维护ET/CS/描述符及扩展元数据布局、指针范围、容量、NULL和READY后冻结合同。
5. 维护事件FIFO队首、POP、IRQ、错误锁存和诊断，让软件正确消费结果和重用资源。

### 5.2 本轮应新增到成员7汇报的工作

- 完成CM的AHB/XBAR分层及REG/EM事务适配，覆盖真实完成、反压、字节写和复位响应边界。
- 完成CM扩展ABI配置、调度网格/安全配置保护，支持软件CCM命令及结果接口。
- 完成中断状态、mask/W1C及事件合并，保证同时置位与清除时的规定优先关系。
- 完成EM各客户端访问统计、地址范围、首错信息及冻结诊断。
- 共同核验休眠时常开主机访问、核心访问限制、EM保留和唤醒后响应；维护终态POP与ET释放接口。

### 5.3 代码与RW原模块

| 功能 | 当前代码 | RW对应 |
| --- | --- | --- |
| AHB接口及REG/EM子接口 | `CM/rw_cm_ahb_if/verilog/rtl/`三个RTL | CM同名ahb_if、ahb2reg、ahb2em |
| XBAR接口及REG/EM子接口 | `CM/rw_cm_xbar_if/verilog/rtl/`三个RTL | CM同名xbar_if、xbar2reg、xbar2em |
| 中断和诊断 | `CM/rw_cm_int_cntl/`、`CM/rw_cm_diag_cntl/` | CM同名模块 |
| CM扩展寄存器 | `CM/rw_cm_misc/sle_regs/verilog/rtl/rw_cm_sle_regs.v` | 新增，无一对一RW原模块 |
| 原业务寄存器和共享EM | `rw_ble_reg/verilog/rtl/rw_ble_reg.v`、`rw_ble_em_cntl/verilog/rtl/rw_ble_em_cntl.v` | BLE同名模块 |
| 事件FIFO与板级总线桥 | `common/rtl/sle_event_fifo.v`、`board/rtl/sle_axi_xbar.v` | 新增 |

成员7管理共享EM和资源交接合同，成员5负责Payload及描述符的实际包级读写。ET的owned真值和ET终态在成员6的调度器中，不另外建立第二套所有权状态。Buffer池分配、防重叠和软件句柄代次仍由软件合同管理，不能宣称存在尚未实现的硬件分配器。

### 5.4 验证责任与汇报用语

重点维护寄存器、总线、EM/复位、非法指针、FIFO/IRQ/诊断，以及与成员6共同的睡眠访问和内存保留检查。

可汇报为：**负责主机总线、寄存器、共享内存和资源交接，完成CM总线与中断诊断接口，并验证128KiB EM、字节写、复位、事件消费和休眠保留。**

## 6 跨成员接口与唯一主责

| 对象或流程 | 唯一真值或实现主责 | 协作条件 |
| --- | --- | --- |
| READY及配置 | 成员7实现主机/EM访问，成员6接收commit | 软件先写完对象与数据；提交时刻按真实完成捕获 |
| job任务 | 成员6派发，成员5执行 | valid/ready同时保持索引、CS、模式和目标时间 |
| owned与ET终态 | 成员6调度器 | 成员7据此冻结配置，并在终态消费后返回terminal_pop |
| 描述符合同及写回 | 成员7定义布局；成员5实现包结果写回 | 数据及状态写完再报告包事实；成员6另写ET状态 |
| 事件与IRQ | 成员5产生收发事实，成员6产生调度终态；成员7保存和公开 | 先前事实与访问处理完再终态，读不弹出，POP才消费 |
| 共享EM与私有CCM RAM | 共享EM归成员7；私有CCM RAM归成员5 | 分别维护各自控制器、读有效、复位与完成语义 |
| 时间Nonce | 成员6提供时间/day/generation；成员5构造并执行安全处理 | 成员7管理配置冻结；当前只支持适用单帧TX或RX |
| 软件CCM DMA | 成员5执行 | 成员6处理scheduler端口独占/调度暂停，成员7管理寄存器与内存合同 |
| 休眠 | 成员6控制 | 成员5确认执行/安全/PHY停稳；成员7确认EM、事件和主机条件 |
| 系统CDC与复位 | 成员5维护公共基础与连接 | 成员6复核时钟门控/时间交接，成员7复核主机/EM响应 |

## 7 最新验收成果如何归属

本轮已完成的是**CM参考架构下的新SLE公共模块及P101数字功能验收**，使用数字接口测试器。仿真、实现源哈希与同一镜像的三轮结果已核对一致。

- 95项CM映射完成：36项同名实现、3项共用新写AES正向变换、56项按配置排除。
- 28项仿真全部通过。
- 新镜像三轮重新初始化和下载，每轮87/87通过；每轮含10,000次休眠/唤醒及完整EM保留检查。
- 完整综合、布局布线与bitstream通过；20MHz setup余量20.997ns、hold余量0.043ns；自有BRAM异步控制违规已消除。
- 镜像SHA256：`827173e6b9bb1ca6fac9ed1540a12e894bc8b9f4ba84b46df34e7c1f72c5314b`。

以上作为三人共同的系统成果。成员5牵头系统构建、镜像连接和测试执行；成员6对时间/调度/共存/休眠用例负责；成员7对总线/寄存器/EM/事件/诊断用例负责。三人分别提交模块测试，跨模块场景共同核对，不把重复执行次数写成新增用例种类。

长压力按要求未重启，不计压力通过；组合验收中包含30分钟压力的总标志仍未通过，不否定本次约定范围的功能验收。真实PHY、射频、HMAC-SM3、密钥协商与派生、独立晶振精度和整机功耗不包含在本次结论。slot/day Nonce限单帧TX/RX，链式/连续/双向安全活动使用载荷计数配置。

## 8 代码维护与后续方向

- 成员5继续维护安全路径和包执行回归，牵头真实PHY接口补齐后的接入及集成。
- 成员6继续维护调度、跳频及休眠，配合真实PHY校核时间预算和窗口；不把数字停钟测试作为独立晶振或功耗验收。
- 成员7继续维护主机与资源接口，为实际软件接入提供发布、消费、回收和诊断合同。
- 更改生成代码时同步维护`tools/integrate.py`、`tools/generate_boundaries.py`或`board/generate.py`；功能或源码变化后重新核对匹配镜像的验证证据。

以下逐文件清单沿用唯一主责原则，模块名称一项不漏；文件数不用于判断个人工作量。

## 附录A 当前RTL逐文件分工与RW原模块对应

下列链接相对本文件指向当前代码。RW列中“包内路径”的文件名即原模块名；以映射清单为依据，不把当前功能反推成RW原始功能。原模块源码未在本文复制。

本次核对：核心filelist有90个RTL，板级filelist有96个RTL（含6个板测RTL）。主责分配为成员5 54个、成员6 29个、成员7 13个。文件数量不代表工作量。BLE原43项全部覆盖；CM原95项中36项同名实现、3项等效合并、56项按配置排除。

### A5 成员5逐文件清单

| 编号 | 当前模块和代码 | 当前功能 | RW源码对应 |
|---|---|---|---|
| 5-01 | [`rw_cm_aes_cipher_decipher`](../CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_cipher_decipher.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_cipher_decipher.v` | CCM使用的AES正向轮数据通路；名称不表示实现逆向AES块解密。 | CM.zip：`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_cipher_decipher.v`（同名实现） |
| 5-02 | [`rw_cm_aes_fsm`](../CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_fsm.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_fsm.v` | AES启动接收、十轮时序及完成脉冲。 | CM.zip：`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_fsm.v`（同名实现） |
| 5-03 | [`rw_cm_aes_keyexpansion`](../CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_keyexpansion.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_keyexpansion.v` | AES-128轮密钥与Rcon扩展。 | CM.zip：`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_keyexpansion.v`（同名实现） |
| 5-04 | [`rw_cm_aes_mixcolumns`](../CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_mixcolumns.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_mixcolumns.v` | AES正向列混合；也承接原bidir列混合模块的适用职责。 | CM.zip：`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_bidir_mixcolumns.v`（等效合并）<br>CM.zip：`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_mixcolumns.v`（同名实现） |
| 5-05 | [`rw_cm_aes_sbox`](../CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_sbox.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_sbox.v` | AES正向字节替换；也承接原bidir S盒的适用职责。 | CM.zip：`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_bidir_sbox.v`（等效合并）<br>CM.zip：`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_sbox.v`（同名实现） |
| 5-06 | [`rw_cm_aes_shiftrows`](../CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_shiftrows.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_shiftrows.v` | AES正向行移位；也承接原bidir行移位的适用职责。 | CM.zip：`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_bidir_shiftrows.v`（等效合并）<br>CM.zip：`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_shiftrows.v`（同名实现） |
| 5-07 | [`rw_cm_aes_top`](../CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_top.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_top.v` | AES块/密钥锁存及轮运算控制和数据通路集成。 | CM.zip：`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_aes_top.v`（同名实现） |
| 5-08 | [`rw_cm_ccm_top`](../CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_ccm_top.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_ccm_top.v` | CCM私有Payload BRAM、同步RAM控制与读有效时序，CTR/CBC-MAC、4B MIC、复位/中止及独立向量恢复。 | CM.zip：`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_ccm_top.v`（同名实现） |
| 5-09 | [`rw_cm_crypto_engine`](../CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_crypto_engine.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_crypto_engine.v` | 对包执行器提供安全数据存储和CCM操作接口。 | CM.zip：`CM/rw_cm_crypto_engine/verilog/rtl/rw_cm_crypto_engine.v`（同名实现） |
| 5-10 | [`sle_cm_crypto_dma`](../CM/rw_cm_crypto_engine/verilog/rtl/sle_cm_crypto_dma.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/sle_cm_crypto_dma.v` | 新增软件CCM命令读取、输入输出搬运及结果ACK后完成。 | 新增；无一对一RW原模块 |
| 5-11 | [`sle_cm_sm4_cipher`](../CM/rw_cm_crypto_engine/verilog/rtl/sle_cm_sm4_cipher.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/sle_cm_sm4_cipher.v` | 新增SM4块密码执行器。 | 新增；无一对一RW原模块 |
| 5-12 | [`sle_cm_sm4_keyexpansion`](../CM/rw_cm_crypto_engine/verilog/rtl/sle_cm_sm4_keyexpansion.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/sle_cm_sm4_keyexpansion.v` | 新增SM4轮密钥扩展。 | 新增；无一对一RW原模块 |
| 5-13 | [`sle_cm_sm4_round`](../CM/rw_cm_crypto_engine/verilog/rtl/sle_cm_sm4_round.v)<br>`CM/rw_cm_crypto_engine/verilog/rtl/sle_cm_sm4_round.v` | 新增SM4轮变换。 | 新增；无一对一RW原模块 |
| 5-14 | [`rw_cm_reset_sync`](../CM/rw_cm_misc/reset/verilog/rtl/rw_cm_reset_sync.v)<br>`CM/rw_cm_misc/reset/verilog/rtl/rw_cm_reset_sync.v` | 复位释放同步与系统复位域集成；配合无旧完成脉冲及停稳验证。 | 新增；无一对一RW原模块 |
| 5-15 | [`dual_edges_synchro`](../CM/rw_cm_misc/synchronization/verilog/rtl/dual_edges_synchro.v)<br>`CM/rw_cm_misc/synchronization/verilog/rtl/dual_edges_synchro.v` | 同步、边沿检测或脉冲握手基础模块；成员5维护，成员6审核休眠时间交接用法。 | CM.zip：`CM/rw_cm_misc/synchronization/verilog/rtl/dual_edges_synchro.v`（同名实现） |
| 5-16 | [`falling_edge_detector`](../CM/rw_cm_misc/synchronization/verilog/rtl/falling_edge_detector.v)<br>`CM/rw_cm_misc/synchronization/verilog/rtl/falling_edge_detector.v` | 同步、边沿检测或脉冲握手基础模块；成员5维护，成员6审核休眠时间交接用法。 | CM.zip：`CM/rw_cm_misc/synchronization/verilog/rtl/falling_edge_detector.v`（同名实现） |
| 5-17 | [`onehot_synchro`](../CM/rw_cm_misc/synchronization/verilog/rtl/onehot_synchro.v)<br>`CM/rw_cm_misc/synchronization/verilog/rtl/onehot_synchro.v` | 同步、边沿检测或脉冲握手基础模块；成员5维护，成员6审核休眠时间交接用法。 | CM.zip：`CM/rw_cm_misc/synchronization/verilog/rtl/onehot_synchro.v`（同名实现） |
| 5-18 | [`pulse_synchro`](../CM/rw_cm_misc/synchronization/verilog/rtl/pulse_synchro.v)<br>`CM/rw_cm_misc/synchronization/verilog/rtl/pulse_synchro.v` | 同步、边沿检测或脉冲握手基础模块；成员5维护，成员6审核休眠时间交接用法。 | CM.zip：`CM/rw_cm_misc/synchronization/verilog/rtl/pulse_synchro.v`（同名实现） |
| 5-19 | [`pulse_synchro_dst_domain`](../CM/rw_cm_misc/synchronization/verilog/rtl/pulse_synchro_dst_domain.v)<br>`CM/rw_cm_misc/synchronization/verilog/rtl/pulse_synchro_dst_domain.v` | 同步、边沿检测或脉冲握手基础模块；成员5维护，成员6审核休眠时间交接用法。 | CM.zip：`CM/rw_cm_misc/synchronization/verilog/rtl/pulse_synchro_dst_domain.v`（同名实现） |
| 5-20 | [`pulse_synchro_src_domain`](../CM/rw_cm_misc/synchronization/verilog/rtl/pulse_synchro_src_domain.v)<br>`CM/rw_cm_misc/synchronization/verilog/rtl/pulse_synchro_src_domain.v` | 同步、边沿检测或脉冲握手基础模块；成员5维护，成员6审核休眠时间交接用法。 | CM.zip：`CM/rw_cm_misc/synchronization/verilog/rtl/pulse_synchro_src_domain.v`（同名实现） |
| 5-21 | [`pulse_to_pulse_synchro`](../CM/rw_cm_misc/synchronization/verilog/rtl/pulse_to_pulse_synchro.v)<br>`CM/rw_cm_misc/synchronization/verilog/rtl/pulse_to_pulse_synchro.v` | 同步、边沿检测或脉冲握手基础模块；成员5维护，成员6审核休眠时间交接用法。 | CM.zip：`CM/rw_cm_misc/synchronization/verilog/rtl/pulse_to_pulse_synchro.v`（同名实现） |
| 5-22 | [`rising_edge_detector`](../CM/rw_cm_misc/synchronization/verilog/rtl/rising_edge_detector.v)<br>`CM/rw_cm_misc/synchronization/verilog/rtl/rising_edge_detector.v` | 同步、边沿检测或脉冲握手基础模块；成员5维护，成员6审核休眠时间交接用法。 | CM.zip：`CM/rw_cm_misc/synchronization/verilog/rtl/rising_edge_detector.v`（同名实现） |
| 5-23 | [`simple_synchro`](../CM/rw_cm_misc/synchronization/verilog/rtl/simple_synchro.v)<br>`CM/rw_cm_misc/synchronization/verilog/rtl/simple_synchro.v` | 同步、边沿检测或脉冲握手基础模块；成员5维护，成员6审核休眠时间交接用法。 | CM.zip：`CM/rw_cm_misc/synchronization/verilog/rtl/simple_synchro.v`（同名实现） |
| 5-24 | [`rw_cm_jitter_elim_fifo`](../CM/rw_cm_radio_cntl/verilog/rtl/rw_cm_jitter_elim_fifo.v)<br>`CM/rw_cm_radio_cntl/verilog/rtl/rw_cm_jitter_elim_fifo.v` | PHY响应弹性缓冲，保持在途结果归属。 | CM.zip：`CM/rw_cm_radio_cntl/verilog/rtl/rw_cm_jitter_elim_fifo.v`（同名实现） |
| 5-25 | [`rw_cm_radio_cntl`](../CM/rw_cm_radio_cntl/verilog/rtl/rw_cm_radio_cntl.v)<br>`CM/rw_cm_radio_cntl/verilog/rtl/rw_cm_radio_cntl.v` | 原生PHY读请求及结果响应控制，超时与停稳资格处理。 | CM.zip：`CM/rw_cm_radio_cntl/verilog/rtl/rw_cm_radio_cntl.v`（同名实现） |
| 5-26 | [`sle_block_cipher`](../common/rtl/sle_block_cipher.v)<br>`common/rtl/sle_block_cipher.v` | 新增AES/SM4选择及稳定完成结果接口。 | 新增；无一对一RW原模块 |
| 5-27 | [`sle_ccm_stream_tx`](../common/rtl/sle_ccm_stream_tx.v)<br>`common/rtl/sle_ccm_stream_tx.v` | 新增流式TX CCM安全数据通路。 | 新增；无一对一RW原模块 |
| 5-28 | [`sle_cmac`](../common/rtl/sle_cmac.v)<br>`common/rtl/sle_cmac.v` | 新增AES/SM4 CMAC辅助路径。 | 新增；无一对一RW原模块 |
| 5-29 | [`rw_ble_bit_stream`](../rw_ble_bit_stream/verilog/rtl/rw_ble_bit_stream.v)<br>`rw_ble_bit_stream/verilog/rtl/rw_ble_bit_stream.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_bit_stream/verilog/rtl/rw_ble_bit_stream.v`（同名架构对应） |
| 5-30 | [`rw_ble_crc`](../rw_ble_bit_stream/verilog/rtl/rw_ble_crc.v)<br>`rw_ble_bit_stream/verilog/rtl/rw_ble_crc.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_bit_stream/verilog/rtl/rw_ble_crc.v`（同名架构对应） |
| 5-31 | [`rw_ble_lr_fec_enc`](../rw_ble_bit_stream/verilog/rtl/rw_ble_lr_fec_enc.v)<br>`rw_ble_bit_stream/verilog/rtl/rw_ble_lr_fec_enc.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_bit_stream/verilog/rtl/rw_ble_lr_fec_enc.v`（同名架构对应） |
| 5-32 | [`rw_ble_lr_pdecoder`](../rw_ble_bit_stream/verilog/rtl/rw_ble_lr_pdecoder.v)<br>`rw_ble_bit_stream/verilog/rtl/rw_ble_lr_pdecoder.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_bit_stream/verilog/rtl/rw_ble_lr_pdecoder.v`（同名架构对应） |
| 5-33 | [`rw_ble_lr_pdemap`](../rw_ble_bit_stream/verilog/rtl/rw_ble_lr_pdemap.v)<br>`rw_ble_bit_stream/verilog/rtl/rw_ble_lr_pdemap.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_bit_stream/verilog/rtl/rw_ble_lr_pdemap.v`（同名架构对应） |
| 5-34 | [`rw_ble_lr_pdetect`](../rw_ble_bit_stream/verilog/rtl/rw_ble_lr_pdetect.v)<br>`rw_ble_bit_stream/verilog/rtl/rw_ble_lr_pdetect.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_bit_stream/verilog/rtl/rw_ble_lr_pdetect.v`（同名架构对应） |
| 5-35 | [`rw_ble_lr_pmap`](../rw_ble_bit_stream/verilog/rtl/rw_ble_lr_pmap.v)<br>`rw_ble_bit_stream/verilog/rtl/rw_ble_lr_pmap.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_bit_stream/verilog/rtl/rw_ble_lr_pmap.v`（同名架构对应） |
| 5-36 | [`rw_ble_lr_psynchro`](../rw_ble_bit_stream/verilog/rtl/rw_ble_lr_psynchro.v)<br>`rw_ble_bit_stream/verilog/rtl/rw_ble_lr_psynchro.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_bit_stream/verilog/rtl/rw_ble_lr_psynchro.v`（同名架构对应） |
| 5-37 | [`rw_ble_whitening`](../rw_ble_bit_stream/verilog/rtl/rw_ble_whitening.v)<br>`rw_ble_bit_stream/verilog/rtl/rw_ble_whitening.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_bit_stream/verilog/rtl/rw_ble_whitening.v`（同名架构对应） |
| 5-38 | [`rw_ble_list_search_engine`](../rw_ble_list_search_engine/verilog/rtl/rw_ble_list_search_engine.v)<br>`rw_ble_list_search_engine/verilog/rtl/rw_ble_list_search_engine.v` | 流式掩码白名单过滤；由集成层供给地址字段并消费决策。 | BLE.zip：`BLE/rw_ble_list_search_engine/verilog/rtl/rw_ble_list_search_engine.v`（同名架构对应） |
| 5-39 | [`rw_ble_lr_fec_dec`](../rw_ble_lr_fec_dec/verilog/rtl/rw_ble_lr_fec_dec.v)<br>`rw_ble_lr_fec_dec/verilog/rtl/rw_ble_lr_fec_dec.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_lr_fec_dec/verilog/rtl/rw_ble_lr_fec_dec.v`（同名架构对应） |
| 5-40 | [`rw_ble_lr_fec_dec_fifo`](../rw_ble_lr_fec_dec/verilog/rtl/rw_ble_lr_fec_dec_fifo.v)<br>`rw_ble_lr_fec_dec/verilog/rtl/rw_ble_lr_fec_dec_fifo.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_lr_fec_dec/verilog/rtl/rw_ble_lr_fec_dec_fifo.v`（同名架构对应） |
| 5-41 | [`rw_ble_lr_fec_dec_fsm`](../rw_ble_lr_fec_dec/verilog/rtl/rw_ble_lr_fec_dec_fsm.v)<br>`rw_ble_lr_fec_dec/verilog/rtl/rw_ble_lr_fec_dec_fsm.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_lr_fec_dec/verilog/rtl/rw_ble_lr_fec_dec_fsm.v`（同名架构对应） |
| 5-42 | [`rw_ble_lr_fec_dec_viterbi`](../rw_ble_lr_fec_dec/verilog/rtl/rw_ble_lr_fec_dec_viterbi.v)<br>`rw_ble_lr_fec_dec/verilog/rtl/rw_ble_lr_fec_dec_viterbi.v` | 保留RW同名位置的外部PHY弹性数据封装；此处不重做CRC、白化、FEC或解调算法。 | BLE.zip：`BLE/rw_ble_lr_fec_dec/verilog/rtl/rw_ble_lr_fec_dec_viterbi.v`（同名架构对应） |
| 5-43 | [`rw_ble_packet_cntl`](../rw_ble_packet_cntl/verilog/rtl/rw_ble_packet_cntl.v)<br>`rw_ble_packet_cntl/verilog/rtl/rw_ble_packet_cntl.v` | 任务执行主状态机；CS及描述符链读取，TX/RX搬运、安全处理调用、包结果回写、取消与停稳。 | BLE.zip：`BLE/rw_ble_packet_cntl/verilog/rtl/rw_ble_packet_cntl.v`（同名架构对应） |
| 5-44 | [`rw_ble_packet_cntl_em_access_fsm`](../rw_ble_packet_cntl/verilog/rtl/rw_ble_packet_cntl_em_access_fsm.v)<br>`rw_ble_packet_cntl/verilog/rtl/rw_ble_packet_cntl_em_access_fsm.v` | 包侧半字/字访问适配，保持请求、等待ACK，检查对齐与错误。 | BLE.zip：`BLE/rw_ble_packet_cntl/verilog/rtl/rw_ble_packet_cntl_em_access_fsm.v`（同名架构对应） |
| 5-45 | [`rw_ble_packet_cntl_main_fsm`](../rw_ble_packet_cntl/verilog/rtl/rw_ble_packet_cntl_main_fsm.v)<br>`rw_ble_packet_cntl/verilog/rtl/rw_ble_packet_cntl_main_fsm.v` | TX、RX、TX→RX、RX→TX的阶段选择及连续序列结束条件。 | BLE.zip：`BLE/rw_ble_packet_cntl/verilog/rtl/rw_ble_packet_cntl_main_fsm.v`（同名架构对应） |
| 5-46 | [`rw_ble_ral_search_engine`](../rw_ble_ral_search_engine/verilog/rtl/rw_ble_ral_search_engine.v)<br>`rw_ble_ral_search_engine/verilog/rtl/rw_ble_ral_search_engine.v` | 按IRK-ID选择密钥并进行AES/SM4 CMAC标识解析。 | BLE.zip：`BLE/rw_ble_ral_search_engine/verilog/rtl/rw_ble_ral_search_engine.v`（同名架构对应） |
| 5-47 | [`rw_ble_core`](../rw_ble_top/verilog/rtl/rw_ble_core.v)<br>`rw_ble_top/verilog/rtl/rw_ble_core.v` | 核心层级连接；保持RW层级并集成执行路径。 | BLE.zip：`BLE/rw_ble_top/verilog/rtl/rw_ble_core.v`（同名架构对应） |
| 5-48 | [`rw_ble_core_cntl`](../rw_ble_top/verilog/rtl/rw_ble_core_cntl.v)<br>`rw_ble_top/verilog/rtl/rw_ble_core_cntl.v` | 核心控制连接；串接角色策略、包执行及辅助接口。 | BLE.zip：`BLE/rw_ble_top/verilog/rtl/rw_ble_core_cntl.v`（同名架构对应） |
| 5-49 | [`rw_ble_misc_logic`](../rw_ble_top/verilog/rtl/rw_ble_misc_logic.v)<br>`rw_ble_top/verilog/rtl/rw_ble_misc_logic.v` | PHY控制信息打包、帧型及MCS检查、完整长度与CRC字节数处理。 | BLE.zip：`BLE/rw_ble_top/verilog/rtl/rw_ble_misc_logic.v`（同名架构对应） |
| 5-50 | [`rw_ble_top`](../rw_ble_top/verilog/rtl/rw_ble_top.v)<br>`rw_ble_top/verilog/rtl/rw_ble_top.v` | 系统顶层；连接主机、调度、时间、EM、事件、睡眠和PHY接口。 | BLE.zip：`BLE/rw_ble_top/verilog/rtl/rw_ble_top.v`（同名架构对应） |
| 5-51 | [`sle_board_axi`](../board/rtl/sle_board_axi.v)<br>`board/rtl/sle_board_axi.v` | 新增板级AXI和测试控制窗口连接。 | 新增；无一对一RW原模块 |
| 5-52 | [`sle_board_core`](../board/rtl/sle_board_core.v)<br>`board/rtl/sle_board_core.v` | 新增链路层、测试器、序列器及板级观察信号集成。 | 新增；无一对一RW原模块 |
| 5-53 | [`sle_board_sequence`](../board/rtl/sle_board_sequence.v)<br>`board/rtl/sle_board_sequence.v` | 新增板上指令序列执行；精确提交、竞争和压力场景。 | 新增；无一对一RW原模块 |
| 5-54 | [`sle_phy_test`](../board/rtl/sle_phy_test.v)<br>`board/rtl/sle_phy_test.v` | 新增可综合PHY合同测试器；TX检查/反压及RX邮箱注入。 | 新增；无一对一RW原模块 |

### A6 成员6逐文件清单

| 编号 | 当前模块和代码 | 当前功能 | RW源码对应 |
|---|---|---|---|
| 6-01 | [`rw_cm_activity_scheduler`](../CM/rw_cm_activity_scheduler/verilog/rtl/rw_cm_activity_scheduler.v)<br>`CM/rw_cm_activity_scheduler/verilog/rtl/rw_cm_activity_scheduler.v` | 16项ET读取与调度、提交检查、优先级仲裁、owned状态、ET状态回写和终态事件。 | CM.zip：`CM/rw_cm_activity_scheduler/verilog/rtl/rw_cm_activity_scheduler.v`（同名实现） |
| 6-02 | [`sle_schedule_grid`](../CM/rw_cm_activity_scheduler/verilog/rtl/sle_schedule_grid.v)<br>`CM/rw_cm_activity_scheduler/verilog/rtl/sle_schedule_grid.v` | 新增25/50/75/100/125µs调度网格合法性检查；不移动目标时刻。 | 新增；无一对一RW原模块 |
| 6-03 | [`rw_cm_coex_if`](../CM/rw_cm_coex_if/verilog/rtl/rw_cm_coex_if.v)<br>`CM/rw_cm_coex_if/verilog/rtl/rw_cm_coex_if.v` | 对外共存信号边界与授权条件。 | CM.zip：`CM/rw_cm_coex_if/verilog/rtl/rw_cm_coex_if.v`（同名实现） |
| 6-04 | [`rw_cm_timing_gen`](../CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen.v)<br>`CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen.v` | 125µs粗时间、0.5µs细时间、三个定时器及时间保持/恢复接口。 | CM.zip：`CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen.v`（同名实现） |
| 6-05 | [`rw_cm_timing_gen_coex`](../CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen_coex.v)<br>`CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen_coex.v` | 根据稳定的同域忙状态与本地/对端优先级计算共存授权。 | CM.zip：`CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen_coex.v`（同名实现） |
| 6-06 | [`rw_cm_timing_gen_fsm`](../CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen_fsm.v)<br>`CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen_fsm.v` | 休眠准入、停钟/开钟握手、唤醒条件及时间恢复流程。 | CM.zip：`CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen_fsm.v`（同名实现） |
| 6-07 | [`rw_cm_timing_gen_lp`](../CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen_lp.v)<br>`CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen_lp.v` | 独立低速时钟下的有理时间累计与保时。 | CM.zip：`CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen_lp.v`（同名实现） |
| 6-08 | [`rw_cm_timing_gen_resync`](../CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen_resync.v)<br>`CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen_resync.v` | 常开域单拍时间推进，处理phase、粗细时间和安全day的进位，支持时间恢复。 | CM.zip：`CM/rw_cm_timing_gen/verilog/rtl/rw_cm_timing_gen_resync.v`（同名实现） |
| 6-09 | [`rw_cm_wlan_coex_cntl`](../CM/rw_cm_wlan_coex_cntl/verilog/rtl/rw_cm_wlan_coex_cntl.v)<br>`CM/rw_cm_wlan_coex_cntl/verilog/rtl/rw_cm_wlan_coex_cntl.v` | 共存请求、优先级、授权及撤回控制。 | CM.zip：`CM/rw_cm_wlan_coex_cntl/verilog/rtl/rw_cm_wlan_coex_cntl.v`（同名实现） |
| 6-10 | [`rw_ble_event_cntl`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl.v` | 集成角色模式检查、CS解析、活动计时、扫描及共存策略。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl.v`（同名架构对应） |
| 6-11 | [`rw_ble_event_cntl_advert`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_advert.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_advert.v` | 广播TX的角色选择与模式合法性策略；不承担软件协议协商。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_advert.v`（同名架构对应） |
| 6-12 | [`rw_ble_event_cntl_bismaster`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_bismaster.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_bismaster.v` | BIS发送窗口的角色选择与模式合法性策略；不承担软件协议协商。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_bismaster.v`（同名架构对应） |
| 6-13 | [`rw_ble_event_cntl_bisslave`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_bisslave.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_bisslave.v` | BIS接收窗口的角色选择与模式合法性策略；不承担软件协议协商。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_bisslave.v`（同名架构对应） |
| 6-14 | [`rw_ble_event_cntl_cismaster`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_cismaster.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_cismaster.v` | CIS类G窗口的角色选择与模式合法性策略；不承担软件协议协商。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_cismaster.v`（同名架构对应） |
| 6-15 | [`rw_ble_event_cntl_cisslave`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_cisslave.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_cisslave.v` | CIS类T窗口的角色选择与模式合法性策略；不承担软件协议协商。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_cisslave.v`（同名架构对应） |
| 6-16 | [`rw_ble_event_cntl_em_manager`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_em_manager.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_em_manager.v` | CS字段解析和指针/模式/时间参数合法性检查；不是Buffer池分配器。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_em_manager.v`（同名架构对应） |
| 6-17 | [`rw_ble_event_cntl_iso0master`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_iso0master.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_iso0master.v` | 同步G角色的角色选择与模式合法性策略；不承担软件协议协商。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_iso0master.v`（同名架构对应） |
| 6-18 | [`rw_ble_event_cntl_iso0slave`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_iso0slave.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_iso0slave.v` | 同步T角色的角色选择与模式合法性策略；不承担软件协议协商。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_iso0slave.v`（同名架构对应） |
| 6-19 | [`rw_ble_event_cntl_main`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_main.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_main.v` | 活动active状态、取消转发和模式错误；不是完整任务执行器。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_main.v`（同名架构对应） |
| 6-20 | [`rw_ble_event_cntl_master`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_master.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_master.v` | G角色的角色选择与模式合法性策略；不承担软件协议协商。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_master.v`（同名架构对应） |
| 6-21 | [`rw_ble_event_cntl_pti`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_pti.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_pti.v` | 按活动优先级及TX/RX状态生成PTI与共存许可。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_pti.v`（同名架构对应） |
| 6-22 | [`rw_ble_event_cntl_scanch`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_scanch.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_scanch.v` | 根据扫描信道图选择和推进扫描信道。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_scanch.v`（同名架构对应） |
| 6-23 | [`rw_ble_event_cntl_scaninit`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_scaninit.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_scaninit.v` | 扫描/发现的角色选择与模式合法性策略；不承担软件协议协商。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_scaninit.v`（同名架构对应） |
| 6-24 | [`rw_ble_event_cntl_slave`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_slave.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_slave.v` | T角色的角色选择与模式合法性策略；不承担软件协议协商。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_slave.v`（同名架构对应） |
| 6-25 | [`rw_ble_event_cntl_test`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_test.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_test.v` | 测试角色的角色选择与模式合法性策略；不承担软件协议协商。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_test.v`（同名架构对应） |
| 6-26 | [`rw_ble_event_cntl_timers`](../rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_timers.v)<br>`rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_timers.v` | 活动内经过时间、最短/最长时间判断。 | BLE.zip：`BLE/rw_ble_event_cntl/verilog/rtl/rw_ble_event_cntl_timers.v`（同名架构对应） |
| 6-27 | [`rw_ble_freq_select`](../rw_ble_freq_select/verilog/rtl/rw_ble_freq_select.v)<br>`rw_ble_freq_select/verilog/rtl/rw_ble_freq_select.v` | SLE PERM/MAM计算与数据信道重映射。 | BLE.zip：`BLE/rw_ble_freq_select/verilog/rtl/rw_ble_freq_select.v`（同名架构对应） |
| 6-28 | [`rw_ble_top_tglp_ext`](../rw_ble_top/verilog/rtl/rw_ble_top_tglp_ext.v)<br>`rw_ble_top/verilog/rtl/rw_ble_top_tglp_ext.v` | 低速时间保持模块的顶层封装。 | BLE.zip：`BLE/rw_ble_top/verilog/rtl/rw_ble_top_tglp_ext.v`（同名架构对应） |
| 6-29 | [`sle_board_clock_gate`](../board/rtl/sle_board_clock_gate.v)<br>`board/rtl/sle_board_clock_gate.v` | 7系列器件主时钟门控；检查实际停钟/恢复，常开主机与调试域继续运行。 | 新增；无一对一RW原模块 |

### A7 成员7逐文件清单

| 编号 | 当前模块和代码 | 当前功能 | RW源码对应 |
|---|---|---|---|
| 7-01 | [`rw_cm_ahb_if`](../CM/rw_cm_ahb_if/verilog/rtl/rw_cm_ahb_if.v)<br>`CM/rw_cm_ahb_if/verilog/rtl/rw_cm_ahb_if.v` | AHB-Lite主机接入及寄存器/EM事务适配，处理访问完成和错误。 | CM.zip：`CM/rw_cm_ahb_if/verilog/rtl/rw_cm_ahb_if.v`（同名实现） |
| 7-02 | [`rw_cm_ahb_if_ahb2em`](../CM/rw_cm_ahb_if/verilog/rtl/rw_cm_ahb_if_ahb2em.v)<br>`CM/rw_cm_ahb_if/verilog/rtl/rw_cm_ahb_if_ahb2em.v` | AHB-Lite主机接入及寄存器/EM事务适配，处理访问完成和错误。 | CM.zip：`CM/rw_cm_ahb_if/verilog/rtl/rw_cm_ahb_if_ahb2em.v`（同名实现） |
| 7-03 | [`rw_cm_ahb_if_ahb2reg`](../CM/rw_cm_ahb_if/verilog/rtl/rw_cm_ahb_if_ahb2reg.v)<br>`CM/rw_cm_ahb_if/verilog/rtl/rw_cm_ahb_if_ahb2reg.v` | AHB-Lite主机接入及寄存器/EM事务适配，处理访问完成和错误。 | CM.zip：`CM/rw_cm_ahb_if/verilog/rtl/rw_cm_ahb_if_ahb2reg.v`（同名实现） |
| 7-04 | [`rw_cm_diag_cntl`](../CM/rw_cm_diag_cntl/verilog/rtl/rw_cm_diag_cntl.v)<br>`CM/rw_cm_diag_cntl/verilog/rtl/rw_cm_diag_cntl.v` | 所有EM客户端访问统计、地址范围、首个故障与诊断冻结。 | CM.zip：`CM/rw_cm_diag_cntl/verilog/rtl/rw_cm_diag_cntl.v`（同名实现） |
| 7-05 | [`rw_cm_int_cntl`](../CM/rw_cm_int_cntl/verilog/rtl/rw_cm_int_cntl.v)<br>`CM/rw_cm_int_cntl/verilog/rtl/rw_cm_int_cntl.v` | 中断状态、屏蔽、清除及IRQ汇合。 | CM.zip：`CM/rw_cm_int_cntl/verilog/rtl/rw_cm_int_cntl.v`（同名实现） |
| 7-06 | [`rw_cm_sle_regs`](../CM/rw_cm_misc/sle_regs/verilog/rtl/rw_cm_sle_regs.v)<br>`CM/rw_cm_misc/sle_regs/verilog/rtl/rw_cm_sle_regs.v` | 新增CM ABI寄存器，调度网格、安全时间上下文及配置保护。 | 新增；无一对一RW原模块 |
| 7-07 | [`rw_cm_xbar_if`](../CM/rw_cm_xbar_if/verilog/rtl/rw_cm_xbar_if.v)<br>`CM/rw_cm_xbar_if/verilog/rtl/rw_cm_xbar_if.v` | XBAR主机接入及寄存器/EM事务适配，保持请求直到真实完成。 | CM.zip：`CM/rw_cm_xbar_if/verilog/rtl/rw_cm_xbar_if.v`（同名实现） |
| 7-08 | [`rw_cm_xbar_if_xbar2em`](../CM/rw_cm_xbar_if/verilog/rtl/rw_cm_xbar_if_xbar2em.v)<br>`CM/rw_cm_xbar_if/verilog/rtl/rw_cm_xbar_if_xbar2em.v` | XBAR主机接入及寄存器/EM事务适配，保持请求直到真实完成。 | CM.zip：`CM/rw_cm_xbar_if/verilog/rtl/rw_cm_xbar_if_xbar2em.v`（同名实现） |
| 7-09 | [`rw_cm_xbar_if_xbar2reg`](../CM/rw_cm_xbar_if/verilog/rtl/rw_cm_xbar_if_xbar2reg.v)<br>`CM/rw_cm_xbar_if/verilog/rtl/rw_cm_xbar_if_xbar2reg.v` | XBAR主机接入及寄存器/EM事务适配，保持请求直到真实完成。 | CM.zip：`CM/rw_cm_xbar_if/verilog/rtl/rw_cm_xbar_if_xbar2reg.v`（同名实现） |
| 7-10 | [`sle_event_fifo`](../common/rtl/sle_event_fifo.v)<br>`common/rtl/sle_event_fifo.v` | 新增事件FIFO；队首一致性、POP、容量与溢出。 | 新增；无一对一RW原模块 |
| 7-11 | [`rw_ble_em_cntl`](../rw_ble_em_cntl/verilog/rtl/rw_ble_em_cntl.v)<br>`rw_ble_em_cntl/verilog/rtl/rw_ble_em_cntl.v` | 128KiB共享BRAM，host/scheduler/packet仲裁、字节写和ACK/fault；同步RAM控制。 | BLE.zip：`BLE/rw_ble_em_cntl/verilog/rtl/rw_ble_em_cntl.v`（同名架构对应） |
| 7-12 | [`rw_ble_reg`](../rw_ble_reg/verilog/rtl/rw_ble_reg.v)<br>`rw_ble_reg/verilog/rtl/rw_ble_reg.v` | 原寄存器、业务扩展银行、命令语义、SNAP、事件队首及FIFO_POP接口。 | BLE.zip：`BLE/rw_ble_reg/verilog/rtl/rw_ble_reg.v`（同名架构对应） |
| 7-13 | [`sle_axi_xbar`](../board/rtl/sle_axi_xbar.v)<br>`board/rtl/sle_axi_xbar.v` | 新增AXI单笔事务到XBAR桥；独立AW/W握手、字节使能及错误响应。 | 新增；无一对一RW原模块 |

## 附录B 当前不采用的CM原模块

以下模块仍登记在原源码映射中，但没有当前执行RTL目标，不分配为本轮必须实现的功能。未来要启用时，应另定功能和验收范围。分类维护联系人仅负责边界说明，不代表已实现。

| RW原模块 | 排除类别 | 边界维护联系人 |
|---|---|---|
| `rw_cm_audio_em_access_cntl` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_audio_path` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_audio_sequencer` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_alaw2linear` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_aulaw` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_linear2alaw` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_linear2ulaw` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_transcoder` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_ulaw2linear` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_aes_fsm_decipher` | CCM使用正向块密码；不采用独立AES逆运算路径 | 成员5 |
| `rw_cm_aes_invmixcolumns` | CCM使用正向块密码；不采用独立AES逆运算路径 | 成员5 |
| `rw_cm_aes_keyexpansion_decipher` | CCM使用正向块密码；不采用独立AES逆运算路径 | 成员5 |
| `rw_cm_allpassh1y11` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_allpassh2y11` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_allpassh2y21` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_allpassh3y11` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_allpassh3y21` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_allpassh3y22` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_cvsd` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_cvsd_context_reg` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_cvsd_control` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_cvsd_decimator` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_cvsd_decoder` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_cvsd_depacketiser` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_cvsd_encoder` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_cvsd_interpolator` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_cvsd_packetiser` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_coex_resync` | 当前P101配置不启用外部MWS/WCI平台接口 | 成员6 |
| `rw_cm_local_sam_cntl` | 当前P101配置不启用外部MWS/WCI平台接口 | 成员6 |
| `rw_cm_mws_coex_cntl` | 当前P101配置不启用外部MWS/WCI平台接口 | 成员6 |
| `rw_cm_mws_coex_core` | 当前P101配置不启用外部MWS/WCI平台接口 | 成员6 |
| `rw_cm_mws_sam_cntl` | 当前P101配置不启用外部MWS/WCI平台接口 | 成员6 |
| `rw_cm_peer_sam_cntl` | 当前P101配置不启用外部MWS/WCI平台接口 | 成员6 |
| `rw_cm_wci_clk_generation` | 当前P101配置不启用外部MWS/WCI平台接口 | 成员6 |
| `rw_cm_wci_em_access_fsm` | 当前P101配置不启用外部MWS/WCI平台接口 | 成员6 |
| `rw_cm_wci_if` | 当前P101配置不启用外部MWS/WCI平台接口 | 成员6 |
| `rw_cm_wci_rx` | 当前P101配置不启用外部MWS/WCI平台接口 | 成员6 |
| `rw_cm_wci_tx` | 当前P101配置不启用外部MWS/WCI平台接口 | 成员6 |
| `rw_cm_pcm` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_pcm_em_interface` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_pcm_formatter` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_pcm_pll` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_pcm_serdes` | 蓝牙音频、PCM或编解码功能不在当前范围 | 成员5 |
| `rw_cm_ble_iso_if` | 蓝牙或厂商专用无线接口/算法由外部SLE PHY合同取代 | 成员5 |
| `rw_cm_btipt_cntl` | 蓝牙或厂商专用无线接口/算法由外部SLE PHY合同取代 | 成员5 |
| `rw_cm_calypso_cntl` | 蓝牙或厂商专用无线接口/算法由外部SLE PHY合同取代 | 成员5 |
| `rw_cm_correlator` | 蓝牙或厂商专用无线接口/算法由外部SLE PHY合同取代 | 成员5 |
| `rw_cm_df_cntl_if` | 蓝牙或厂商专用无线接口/算法由外部SLE PHY合同取代 | 成员5 |
| `rw_cm_edr_if` | 蓝牙或厂商专用无线接口/算法由外部SLE PHY合同取代 | 成员5 |
| `rw_cm_extrc_cntl` | 蓝牙或厂商专用无线接口/算法由外部SLE PHY合同取代 | 成员5 |
| `rw_cm_icytrx_v2_cntl` | 蓝牙或厂商专用无线接口/算法由外部SLE PHY合同取代 | 成员5 |
| `rw_cm_ripple_cntl` | 蓝牙或厂商专用无线接口/算法由外部SLE PHY合同取代 | 成员5 |
| `rw_cm_serial_txrx_if` | 蓝牙或厂商专用无线接口/算法由外部SLE PHY合同取代 | 成员5 |
| `rw_cm_timing_gen_abtrain` | 蓝牙音频或AB train时间参考不属当前SLE时基 | 成员6 |
| `rw_cm_timing_gen_audio` | 蓝牙音频或AB train时间参考不属当前SLE时基 | 成员6 |
| `rw_cm_timing_gen_pcmref_timing` | 蓝牙音频或AB train时间参考不属当前SLE时基 | 成员6 |

## 附录C 本轮核对依据

- `docs/CM_ACCEPTANCE.md`与`build/board/cm_acceptance.json`：当前约定范围的功能验收结论。
- `build/test_results.json`、`build/board/manifest.json`、`build/board/rounds/1..3/`：仿真、源码、镜像与三轮板测。
- `docs/CM_INTERFACE.md`与`docs/INTERFACE.md`：当前接口及资源合同。
- `docs/module_allocation.json`、`docs/cm_mapping.json`、`rtl.f`、`board.f`：原模块对应和当前构建清单。
- `build/SLE_CM_P101_NO_PHY_FUNCTIONAL.zip`：本轮功能交付包；不把长压力、真实PHY或射频计入其中的功能结论。

当前分工文档更新了维护范围和可汇报内容，未修改RTL或重新执行硬件验收。整体HTML与飞书汇报的原快照保持独立，本次不向其加入成员分工。
