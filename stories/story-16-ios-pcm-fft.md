# Story 16：iOS PCM 旁路与频谱推送

## 目标
在 iOS 侧为 AVPlayer 播放链路接入音频 tap/旁路，获取 PCM 帧并通过 EventChannel 推送到 Dart，完成基础频谱（FFT）计算推送，使波形/频谱 UI 能实时展示本地/HTTP 音频数据。

## 测试优先（TDD）
- ✔ [1] 补充测试计划（占位）：约定事件格式、时间戳/帧率与节流规则，覆盖 HTTP（ATS 例外）与本地 asset（沙盒拷贝）两类输入，仅限真机（iOS 15+，如 iPhone 12/13/14），模拟器不验。
- ✔ [2] 添加占位/跳过用例：`soundwave_player/test/ios_pcm_fft_placeholder.dart`，模拟 PCM/频谱事件的缓冲、时间戳回退处理，因 iOS 原生旁路未落地故全局 Skip。

## 开发任务
- ✔ [3] AVPlayer 旁路：在 `AVPlayerItem` 上添加 `AVAudioMix` + `audioTapProcessor` 获取 PCM 16/32bit，保持播放正常。
- ✖ [4] PCM 事件推送：后台线程/队列聚合帧，按帧率（~30fps）推到 `pcm` EventChannel，字段 `sequence`、`timestampMs`（基于 `currentTime()`）、`samples`；seek/stop/load 时重置计数/清空队列并上报丢弃。
- ✖ [5] 频谱计算：使用 Accelerate/vDSP 对旁路 PCM 窗口化+FFT（后续可替换为 KissFFT 保持跨平台一致性），推送 `spectrum` 事件（`sequence`、`timestampMs`、`bins`、`binHz`），与 PCM 同步重置，限制 CPU（可抽稀频率/下采样）。
- ✖ [6] 资源加载与配置：支持 HTTP（必要时 Info.plist ATS 例外）和本地 asset（拷贝到沙盒后播放）；确保解码与旁路兼容。
- ✖ [7] 状态/生命周期：处理中断/路由/后台前台切换时，暂停/恢复旁路，避免旧数据污染；释放时移除 tap 与观察者。
- ✖ [8] 日志与诊断：在 tap/推送链路关键节点打 Info 级日志，便于 `flutter run`/Xcode 控制台排查。

## 完成标准（DoD）
- ✖ [9] 在 iOS 真机上播放 HTTP 或打包 asset，波形/频谱 UI 实时刷新（Dart 层无需额外修改）。
- ✖ [10] 事件格式符合设计，序列/时间戳单调；seek/stop/load 后无旧数据混入，丢帧计数生效。
- ✖ [11] 构建通过；占位测试计划/用例已更新并标注原因。

### T1 测试计划（占位）
- 事件格式：PCM 事件包含 `sequence:int`、`timestampMs:int64`（来源于 `currentTime()`）、`samples:float[]`；频谱事件包含 `sequence`、`timestampMs`、`bins:float[]`、`binHz:double`。丢帧时附 `droppedBefore:int`。
- 序列与时间戳：同一事件流单调递增；`seek/stop/load` 后序列与时间基重置且清空队列，旧数据不得混入。
- 帧率与节流：PCM/谱推送 ≤ 30fps；旁路队列上限（如 60 帧）溢出则丢弃最旧并上报丢帧。FFT 可隔帧抽稀/降采样以控 CPU。
- 输入场景：HTTP MP3/AAC（如需 ATS 例外在 Info.plist 开启），本地 asset 拷贝至沙盒后播放，验证两者均收到 PCM/FFT。
- 设备与性能：真机 iOS 15+（iPhone 12/13/14）；播放 60 秒内 CPU 占用不应明显飙升（FFT 抽稀后 < 25% 峰值），内存无持续增长；回到前台后继续推送且序列不中断。
