# Story 03：PCM/谱数据导出模块

## 目标
- 在旁路链路增加数据导出能力，支持 PCM → WAV（44.1kHz/float32/stereo），Spectrum → CSV/JSON（含 binHz/seq/ts），可供 PC 工具分析。

## 测试优先（TDD）
- ✖️ [1] 导出正确性：导出的 WAV/CSV/JSON 与实时事件数据一致（序列、时间戳、binHz），可被 Audacity/Matlab/Python 读取。
- ✅ [2] 门禁：`flutter test`/集成测覆盖导出流程；基础构建通过。（当前以 Dart 单测覆盖导出写入，集成导出待补）
  - PC 校验流程（Python）：读取导出 WAV/CSV/JSON 与实时事件做比对，误差在容差内（PCM bit-exact，谱 L2/最大值 < 1e-3）。

## 开发任务
- ✅ [3] 设计导出接口与存储路径/权限（iOS/Android），实现 PCM/WAV、Spectrum/CSV/JSON 写入。（AudioController 接入 ExportConfig，事件导出可用）
- ✅ [4] 与节流/序号对齐，确保导出不影响实时链路性能。（导出队列有限长，超限丢弃最旧帧并保持写入有序）
- ✖️ [5] 文档与示例更新：说明导出格式、字段、开启方式。
  - 路径与权限：Android 使用 `getExternalFilesDir(Environment.DIRECTORY_MUSIC)`（免权限）；iOS 使用 `documentDirectory`；处理磁盘不足/文件大小上限。
  - 配置开关：`SoundwaveConfig` 增加导出开关/目录/文件前缀，默认关闭；避免影响实时链路性能。
  - 格式细节：WAV 44.1kHz/float32/stereo RIFF 头；CSV/JSON 包含 `sequence`,`timestampMs`,`binHz`,`bins[]`；字段顺序/单位明确。
  - 性能约束：导出线程/队列与节流对齐，限制批次/缓冲写入，避免阻塞 PCM/谱推送。

## 完成标准（DoD）
- ✖️ [6] 导出文件经 PC 工具验证与实时数据一致。
- ✖️ [7] 测试通过（含导出流程）且构建门禁通过。
- ✖️ [8] 文档与示例更新完成。***
