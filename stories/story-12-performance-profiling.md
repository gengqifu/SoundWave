# Story 12：性能调优与 Profiling

## 目标
收集并优化延迟、帧率、CPU/GPU/内存指标，调节节流/缓冲参数，形成性能基线（TDD）。当前聚焦本地播放链路，流式场景待 Story10 恢复后补测。

## 测试优先（TDD）
- ✔ [1] 先编写性能测试脚本：本地播放采集延迟、帧率、CPU/内存基线（Flutter devtools / native trace），流式待 Story10。
- ✔ [2] 长时间播放稳定性用例（≥2h）规划与自动化（可手动触发）。

## 开发任务
- ✔ [3] 添加采样点：解码→缓冲→回放→UI 显示延迟，帧率统计，CPU/内存监控（Flutter DevTools/profile build + native trace）。采样点详见 `soundwave_player/scripts/trace_points.md`。
- ✔ [4] 参数化：节流、缓冲时长、FFT 配置可调；探索合理默认值并记录（新增 ringBufferMs、enableSkiaTracing 下发原生）。
- ✖ [5] 优化：内存复用，回调轻量化，必要时降级帧率；后台暂停策略不计入前台性能。
- ✖ [6] 日志/导出：性能日志可导出/调试查看（profile 包/文本导出）。

## 完成标准（DoD）
- ✖ [7] 性能测试脚本输出指标，达标或有调优记录。
- ✖ [8] 长时间播放验收：无崩溃、内存增长 < 5%。
- ✖ [9] 变更文档：默认参数与调优指南。
