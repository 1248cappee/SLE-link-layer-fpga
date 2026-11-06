# 新写SLE公共模块

CM.zip只提供职责划分参考，其RTL不加入构建。本目录全部实现为SLE
Verilog-2001，权威入口为项目根rtl.f和board.f。95项逐文件对应、端口
变化、职责、资源合同和测试链接见docs/cm_mapping.json。

当前36项同名实现，3个双向AES变换参考文件复用对应的正向变换，56项
按既定配置排除。排除项不生成占位模块，也不宣称具备对应能力。

- activity_scheduler：16项ET所有权、五种调度粒度、固定基础槽提交门槛和终态排序。
- timing_gen：基础时间、三个定时器、常开休眠管理、低速参考及唤醒时间交接。
- ahb_if / xbar_if：寄存器和EM的真实完成、等待、字节写、错误及复位中断事务。
- int_cntl / diag_cntl：原中断合同、CM扩展中断和全部EM客户端诊断统计。
- coex_if / wlan_coex_cntl：请求、授权、拒绝和包边界撤销。
- radio_cntl：冻结SLE PHY接口的控制和邮箱响应缓冲，不实现射频/PHY算法。
- misc：CDC辅助、同步复位释放和独立CM寄存器银行。
- crypto_engine：CCM/BRAM和命令DMA，独立AES轮控/密钥/变换层级，新增SM4层级。

接口、默认值和能力限制以docs/CM_INTERFACE.md为准。特别是时隙/天数
Nonce当前仅允许单帧TX或RX；链式或双向活动使用载荷计数配置。
HMAC-SM3、密钥协商、独立低速晶振和真实PHY/RF不在本次验收范围。

运行tools/sim.ps1执行28项XSim测试。按用户要求，当前功能板测使用
tools/accept_cm.ps1 -SkipPressure；不恢复长压力测试。当前源码、镜像及
实际下载结果一致后才允许打包FUNCTIONAL交付，历史镜像结果不能替代。
