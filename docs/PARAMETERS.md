# 参数与编码清单

参数来自本地输入文件；原表原文及行号在resource_contract.json。以下同时说明实现值和不应混用的语义。

- RW架构时间：312.5us粗步长，原细时间为递减形式。新实现不保留此时基：20MHz、10拍/fine使能，0.5us/fine、递增0..249，125us/slot，30bit粗时间，模2^30回绕。所有比较采用半范围，软件目标距离须小于2^29槽。
- 时间字段宽度：槽号30bit，fine存储10bit但250..1023非法。三定时器均一次性；已到/过期目标立即触发，先写粗细目标再ARM。计时单位不沿用BLE的half-slot或625tick。
- 提前量：T−8槽/1ms由TMR1通知软件Programmer；最晚T−2槽/250us原子发布。硬件捕获READY完成时刻，最小差值500 fine tick；并非从后续轮询读到ET时才计提前量。准备通知与立即发射没有等价关系。
- 容量：ET16项，每项16B；CS146B；TX16B；RX28B；默认EM128KiB；FIFO默认64，允许2..255；EM可配置1024..131072B且为4B整数倍。FIFO计数/读写索引8bit。原260B数据缓冲配置可继续使用；不能因链路层支持2047B而允许260B缓冲写入261B。
- 指针：对象14bit×2B，数据16bit×2B，NULL0。ET16B对齐，其余原对象/数据至少2B；扩展元数据4B对齐。整对象和缓冲末地址也受范围检查，不能只检查起点。
- 长度：链路层wire长度11bit，0..2047；security非零时4B MIC包含在wire长度内，业务长度至多2043。Type3/4的控制数据长度另包含3/4B帧CRC，受相同11bit控制字段限制。A1/B5的8bit长度还会收紧上限。CRC/FEC、导频等不是链路层payload字节。
- 数据顺序：共享内存及payload为小端，word[7:0]是首字节；AES/SM4 block和nonce内部按明确的首字节高位顺序排列，不能将128bit密钥、13B nonce与总线word直接混同。附录F示例在tb_appendix_f中逐字节核对。
- MODE：0TX、1RX、2TX→RX、3RX→TX；其余拒绝。STATUS：0FREE、1READY、2FETCHED、3RUNNING、4DONE、5SKIPPED、6CANCELLED、7ERROR。编码在common/rtl/sle_defs.vh。
- 事件：0NONE、1START、2END、3SKIP、4CANCEL、5ERROR、6TX、7RX。原因：0OK、1LATE、2CONFLICT、3SW_CANCEL、4BAD_DESC、5BUS_FAULT、6WINDOW_END、7NO_BUFFER。收到CRC/MIC失败的RX事实不等价于任务ERROR，也不等价于业务交付成功，须读取结果位。
- 信道：当前实现2.4GHz，数据图76bit，扫描图79bit。PRN/重映射使用SLE算法；固定PHY板级桥的信道76不是通用业务默认信道。其他频段不宣告实现。MCS有效0..12；合法MCS的PHY吞吐/最大包及对应airtime仍由PHY能力约束。
- CRC：0/1是24bit选项，2是32bit，3非法；实际算法位于冻结PHY，不在同名弹性封装中重新计算。
- 安全：0明文、1AES-CCM、2SM4-CCM；密钥128bit、nonce13B、MIC4B、关联数据单字节0。TX/RX分别有39bit包计数和1bit方向。软件提供会话密钥、IV、初值；同一活动内分别推进，最大值用过后不回绕。CM ABI 1.1增加单帧TX/RX的槽号/天数Nonce配置，见CM_INTERFACE.md；链式/连续/双向活动使用载荷计数配置。
- 时长：MIN/MAX、RX窗口、转换间隔和元数据TX空口时长统一以0.5us计，不沿用原BLE字段的旧单位。最大窗口非零，MIN<=MAX；启动新TX前先检查其可靠airtime是否越界。无法仅根据coding_done或tx_done推算实际空口时长。

所有端口位宽及变化以module_mapping.json为准。保留目录、模块名称和对象步长，并不等于保留冲突的BLE编码语义。
