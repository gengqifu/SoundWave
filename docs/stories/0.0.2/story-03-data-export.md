# Story 03：PCM/谱数据导出模块

## 目标
- 在旁路链路增加数据导出能力，支持 PCM → WAV（44.1kHz/float32/stereo），Spectrum → CSV/JSON（含 binHz/seq/ts），可供 PC 工具分析。

## 测试优先（TDD）
- ✖️ [1] 导出正确性：导出的 WAV/CSV/JSON 与实时事件数据一致（序列、时间戳、binHz），可被 Audacity/Matlab/Python 读取。
- ✖️ [2] 门禁：`flutter test`/集成测覆盖导出流程；基础构建通过。

## 开发任务
- ✖️ [3] 设计导出接口与存储路径/权限（iOS/Android），实现 PCM/WAV、Spectrum/CSV/JSON 写入。
- ✖️ [4] 与节流/序号对齐，确保导出不影响实时链路性能。
- ✖️ [5] 文档与示例更新：说明导出格式、字段、开启方式。

## 完成标准（DoD）
- ✖️ [6] 导出文件经 PC 工具验证与实时数据一致。
- ✖️ [7] 测试通过（含导出流程）且构建门禁通过。
- ✖️ [8] 文档与示例更新完成。***
