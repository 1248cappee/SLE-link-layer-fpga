# 链路层及业务接口合同

## 时钟、复位及主机访问

`rw_ble_top` 参数：`EM_BYTES=131072`、`FIFO_DEPTH=64`、`CLK_HZ=20000000`、`HOST_INTERFACE=0`。HOST_INTERFACE=0 选择原形式 XBAR `p_rd/p_wr/p_ad/p_wdata/p_ben/p_wait/p_rdata/p_error`；非零选择 AHB-Lite `hsel/hready_in/haddr/htrans/hwrite/hsize/hwdata/hready/hresp/hrdata`。两种接口不能同时发起访问。地址均为 18 位本地字节地址，板级 REG_BASE/EM_BASE 由平台译码。

寄存器范围 `0x00000..0x00fff`，32 位对齐；EM 窗口 `0x20000..0x3ffff`。AHB 支持 byte/halfword/word，地址/数据阶段分离，非法大小或对齐返回两拍 ERROR。EM 可进行字节使能写；上层半字写须对齐至总线 word 并选择 BE。XBAR 请求和参数保持至 `p_wait=0`，下一事务前撤销请求。主机 RAM 读数据仅在事务完成时有效。

异步低有效硬复位只复位控制状态，不清除 BRAM。软件初始化 ET/CS/描述符池。SOFT_RST 先冻结新任务并取消执行，等待真实 PHY 停稳和全部 EM 事务结束，再清 16 项 ET 状态、FIFO 和控制状态。必须等待 BUSY=0 后回收。PHY 永不提供停稳时，BUSY 会持续，不能用固定等待替代。

BRAM 控制器在时钟边沿同步采样复位，其地址、写数据和使能控制寄存器不使用异步复位。此前已接受的 RAM 写入可以在硬复位采样边沿提交，旧 ACK 被清除；未收到 ACK 不能推断为未写入，硬复位后必须重新初始化所有权对象。板级新增只读 `debug_slot[29:0]`、`debug_fine[9:0]`、`debug_busy`、`debug_errors[4:0]`、`debug_fifo_count[7:0]`、`debug_event[71:0]`，不更改原 SNAP 和 FIFO_POP 语义。

## 原寄存器及队首语义

原目录 104 个地址保持，表“字段定义”中已定义的字段逐项实现；VERSION=`0x534c0100`、RWBLECONF=`0x00100f01`。目录中仅有名称、没有业务位域定义的旧 BLE 寄存器为 RAZ/W0，非零写入报告 BAD_CMD；其 SLE 业务功能使用下述独立窗口。它们不是未声明的 BLE 兼容寄存器。

三个 Timer 为一次性，粗时间 30 位，细时间 0..249；每 10 个 20MHz 时钟递增一次。ARM 时使用半范围比较，等于/已经过去的目标立即到期并清 ARM。写已 ARM 的目标无效且 BAD_CMD。SNAP 同拍锁存 SLOTCLK/FINETIMECNT，后续读取保持；LOAD_TIME 要求调度空闲、队列排空、调度关闭、ARM 全零。

INTSTAT 的 FIFO/ERROR 为电平，Timer/CLOCK 为锁存；INTACK 仅 W1C Timer/CLOCK。ACTFIFOSTAT、当前 RX 描述符指针、START/END/SKIP 时间都来自同一 FIFO 队首；读不弹出，只有 FIFO_POP 消费。空队列 POP 是 BAD_CMD。事件入队前完成相关数据/状态及 DONE 回写；同一任务先收发事实再终态，终态消费前 ET 索引仍有硬件所有权。软件回调、代次及句柄留在软件镜像中。

静态扩展寄存器：0x400=`SLEX`，0x404=ABI 1.0，0x408=EM 字节数，0x40c=FIFO 深度，0x410=PHY 真实能力输入，0x414=`0x1e00fa7d`（30 位粗计数、250 fine/slot、125us）。均 RO。

## 共享内存布局与访问时序

ET 16项×16B，CS 146B，TX 描述符16B，RX 描述符28B；逐半字访问，不扩大原步长，不占用保留字段。原表的具体偏移及字段原样保存在 resource_contract.json 的“对象字段”。CSPTR/NEXTPTR/ETPTR 为14位、2B单位，整对象须处于起始32KiB；数据指针16位、2B单位，指向起始128KiB。NULL=0，不能分配零地址对象。ET 基址16B对齐，原数据/对象至少2B对齐。

EM 三客户端为 host/scheduler/packet，轮询仲裁。客户端请求保持至 ACK，ACK 后撤销请求。接受时锁存请求，下一拍进行同步 BRAM 读/字节写，再下一拍 ACK；读数据与 ACK 同时有效，写 ACK 表示已写完。撤销请求后才允许该客户端再次接受。地址非法时 ACK+fault，不访问 RAM。无独立组合 ready，不得将 request 或“空闲”当成 read_valid。默认128KiB为32K×32bit BRAM。

软件在 T−8槽给 TMR1 编程并开始准备，在不晚于 T−2槽完成写屏障、原子16位发布 READY、写屏障。最小提前量由 READY 写入完成时捕获，等于500 fine tick合法，少于500为 LATE。FREE 的引用对象不被硬件预取。同点按 PRIO1 大者优先，再 ET_IDX 小者，冲突不自动顺延。

READY 后软件必须冻结整组引用对象和 payload，直到终态及此前事件/回调消费完；这是一项主机所有权约束。扩展寄存器银行有 owned 写保护，任意共享 RAM 地址没有硬件访问控制/防恶意主机机制。禁止软件在交接后修改 CS/描述符/数据；需要修改须取消并等待终态。参数化容量改变不改变指针编码上限。

## 业务扩展窗口

每个 ET 使用 `0x800 + ET_IDX*0x80` 的32个32位字，复位全零。READY 到终态 POP 之间拒绝软件写该银行。下文 word 是相对银行的字索引；未列字段写零。

- word0：frame_type[2:0]；control_format[7:3]；MCS[11:8]；CRC_mode[13:12]；bandwidth[15:14]；security[17:16]（0明文、1AES-CCM、2SM4-CCM）；auth_only[18]；role[23:20]；hop[25]、scan[26]、coex[27]。hop与scan不能同时置位。
- word1：LLID[23:0]。word2：frame CRC seed32。word3：CB CRC seed24。
- word4/5：64位控制信息模板，低32位在word4。硬件按帧型/控制格式覆盖长度及MCS字段，其他协议位由软件填写。
- word6：control_info_len[6:0]、whitening[8]、feedback_cbg[9]、pilot_density[11:10]、broadcast[12]、mseq_id[15:13]。
- word7：转换间隔fine tick[15:0]。word8/9：TX/RX 扩展元数据链首，16位、2B指针单位。
- word10/11：RX 初始有效载荷计数低32/高7位，word11[7]为RX方向。word18/19以相同方式提供TX计数和方向。包计数在活动内部保存，TX完成后和RX成功交付后分别加1，重复/CRC/MIC失败不推进RX；耗尽后拒绝下一安全包。重新发布活动前，软件根据事实与结果更新初始值。软件不能为新消息重复使用已有key/IV/counter/direction组合。
- word12..15：128位密钥，word12为最低32位。word16/17：64位初始化基础值，word16最低32位。Type1/2使用同步序列低32位异或，Type3/4使用LLID24位异或。
- word20/21：同步序列低/高32位。word22：固定物理信道[6:0]。word24..26：76位数据信道图；scan时额外使用word26[14:12]表示76..78。

role编码：0广播TX；1扫描；2 G/master；3 T/slave；4/5同步G/T；6/7 CIS类窗口；8/9 BIS发送/接收；10测试。角色子模块检查相应模式，统一包执行器处理CS/链及真实窗口。协议过程状态、接入分配、业务参数选择和软件重传不在这些窗口策略中自动协商。

每个16B扩展元数据对象独立分配，4B对齐，仍用2B单位指针：+0低16为原描述符指针（低14有效），高16为下一元数据指针；+4低11位为TX业务长度/硬件RX实际wire长度，高半字低11位为缓冲容量；+8在TX为预期实际空口时长fine tick，RX为硬件原始D0；+12在RX为结果位。禁止循环链、描述符与元数据错配及容量越界。TX空口时长必须由所选PHY参数可靠计算，硬件据此避免启动越过MAX的新TX；这是软件/PHY合同输入。

RX结果+12：[0]RAM已写、[1]PHY CRC通过、[2]MIC适用、[3]MIC通过、[4]允许最终交付。明文MIC不适用，不能标记为MIC成功。CRC/MIC/重复失败仍写状态并释放邮箱；原RXDONE最后写入。原260B缓冲仍可使用，容量不足拒绝写越界。完整wire长度上限2047B；4B MIC占用wire长度，安全业务最大2043B。控制格式本身限制更小时另外拒绝，例如A1的8位长度。Type3/4控制长度计入帧CRC，因此其业务容量还需减去3/4B帧CRC。

## 原生PHY与需要补充的里程碑

TX `tx_cfg_*` 对应 `sle_tx_mac_iq_top.cfg_*`，payload32bit data/4bit keep/valid/ready/last，支持反压。配置接受只代表锁存配置；coding_done是编码结束，tx_done是I/Q输出结束。二者都不是射频实际空口结束。板级还需连接固定幅度及混频参数，这些由板级PHY/RF配置负责。

真实时序扩展：tx_prepared（待发波形/流水准备完成）、tx_launch（目标时间启动请求）、tx_air_started及其30bit slot/10bit fine、tx_air_done、tx_stop/tx_quiescent；RX需rx_window_started、rx_sync_valid及同步slot/fine、rx_stop/rx_drain_done。所有里程碑必须是实际硬件事实，跨时钟域由板级提供同步/握手；本顶层合同假定在20MHz域。phy_caps低4位分别表示真实TX开始、空口结束、RX同步、drain，缺少任一时拒绝活动，不能给常量来伪装具备能力。

RX native MAC bus 为 req/write/addr/wdata、rvalid/rdata/irq。写为该原生接口的单拍接受方式；每次读须等rvalid，radio controller提供超时错误。先读稳定结果D0，再D4长度、D8存储字数、DC payload，随后邮箱确认3C；错误结果同样释放。停止时还发送FRAME_END、清IRQ，并等待真实drain。没有sync时不填写伪同步时间。

白名单和地址解析由顶层filter_*、resolve_*显式流接口调用，有start/abort、entry_valid/ready/last、result_valid/ready。支持48bit掩码表和按IRK-ID选择的AES/SM4 CMAC低16位解析（消息0..16B）；软件/集成层负责按实际PDU布局供给地址字段并消费决策。这些辅助结果没有在未知PDU偏移处自动拦截业务包。HMAC-SM3及协商不宣告支持。
