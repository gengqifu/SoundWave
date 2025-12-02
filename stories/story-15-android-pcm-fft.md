# Story 15：Android PCM 旁路与频谱推送

## 目标
在 Android 侧基于 ExoPlayer 接入自定义 AudioProcessor/AudioSink，将 PCM 帧旁路并通过 EventChannel 推送到 Dart，完成基础频谱（FFT）计算推送，使波形/频谱 UI 能实时展示本地播放的音频数据。

## 测试优先（TDD）
- ✔ [1] 补充测试计划（占位）：约定事件格式、递增与节流规则如下。
- ✔ [2] 添加占位/跳过用例：例如 `soundwave_player/test/android_pcm_fft_placeholder.dart`，构造模拟事件流验证 Dart 缓冲/波形组件消费数据（若缺运行环境则 `@Skip` 并写明原因）。

## 开发任务
- ✔ [3] 自定义 AudioProcessor/AudioSink hook：截获播放链路 PCM 16/32bit，保持播放正常，将帧写入旁路队列。
- ✔ [4] PCM 事件推送：后台线程按帧率（如 30fps）从队列聚合/推送到 `pcm` EventChannel，字段 `sequence`、`timestampMs`、`samples`，seek/stop/load 时重置计数/时间基并发送丢弃标记。
    - ✔ [5] 频谱计算：对旁路 PCM 做窗口+FFT（先用轻量 Java FFT；后续可替换为 JNI/kissFFT），推送 `spectrum` 事件（`sequence`、`timestampMs`、`bins`、`binHz`），与 PCM 同步重置。
- ✖ [6] 状态/生命周期：seek/stop/load/reset 时清空队列、重置时间基，后台/前台切换不阻塞播放线程，避免旧数据污染。
- ✖ [7] 日志与故障定位：在 PCM/频谱推送链路关键节点打 Info 级日志，便于 logcat 排查。

## 完成标准（DoD）
- ✖ [8] 波形/频谱在现有 demo UI 实时刷新（Dart 层无需额外修改）。
- ✖ [9] 事件格式符合设计，序列/时间戳递增；seek/stop 后无旧数据混入，丢帧计数生效。
- ✖ [10] 构建通过；占位测试计划/用例已更新并标注原因。

### T1 测试计划（占位）
- 事件格式：PCM 事件包含 `sequence:int` 自增、`timestampMs:int64`（播放时间）、`samples:float[]`；频谱事件包含 `sequence`、`timestampMs`、`bins:float[]`、`binHz:double`。
- 序列与时间戳：同一事件流内单调递增；seek/stop/load 后重置为 0/新基准，并丢弃旧队列。
- 丢帧标记：旁路队列溢出或聚合丢弃时推送 `droppedBefore:int` 或 `dropped:true` 标记（与 Dart 缓冲约定一致），确保 UI 可统计丢帧。
- 帧率节流：PCM/谱推送不超过 ~30fps，确保 UI 流畅；队列上限（如 60 帧）溢出即丢弃最旧。
