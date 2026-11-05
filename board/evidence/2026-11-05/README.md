# P101 不接 PHY 板测证据摘要

该目录保存2026-11-05在 P101 进行数字接口测试的部分原始证据。测试镜像使用可综合接口测试器；结果不代表真实 PHY 或射频通过。

- `board_results.json`：44个板测场景的结果与当次 bitstream SHA256。
- `acceptance.json`：仿真、实现、板测及基础 ILA 时间检查的汇总。
- `implementation.json`：目标器件、工作频率和布线后 setup/hold 余量。
- `test_results.json`：22个 XSim 测试及其源文件哈希；仅移除了本机临时目录路径 `stage`。
- `manifest.json`：当次构建的源文件和产物 SHA256；仅移除了本机临时目录路径 `stage`。
- `ila_foundation_full_em.csv`：基础场景的4096点原始 ILA 数据，其中细时间每10个采样递增。
- `events_competition_16.txt`：16项同点竞争时按 FIFO 消费顺序读取的18条事件。

为保留独立验收边界，`.bit/.ltx`、完整44份 ILA 数据、原始工具日志及构建检查点仍按仓库 `.gitignore` 保存在本地 `build/`；本目录中的哈希可用于核对这些本地文件。完整结论、剩余告警和测试边界见 [板测验收报告](../../../docs/BOARD_ACCEPTANCE.md)。
