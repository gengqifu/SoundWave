# SoundWave
移动端音频播放 + 实时可视化（波形 / 频谱）的 Flutter 插件与示例。

## 功能
- 播放本地/流式音频（ExoPlayer/AVPlayer），支持播放控制与前后台切换。
- 实时波形渲染：PCM 分帧抽稀绘制，支持背景/颜色/线宽配置。
- 实时频谱渲染：Hann 窗口 + FFT（Android KissFFT JNI，iOS vDSP，可选 Swift FFT 后备），支持对数频率轴（默认）或线性轴、幅度压缩。
- 数据节流：PCM/频谱事件按 FPS 和批次推送，降低 Platform Channel 开销。

## 快速开始
1) 安装 Flutter 3.x，准备 iOS/Android 运行环境。  
2) 获取依赖：
```bash
cd soundwave_player/example
flutter pub get
```
3) 运行示例：
```bash
flutter run  # 连接真机/模拟器
```
4) 示例页面中点击 `Use bundled sample.mp3`、`Init`、`Load`、`Play` 可查看波形与频谱。

## 频谱样式示例
```dart
const SpectrumStyle(
  barColor: Colors.cyan,
  background: Colors.black,
  barWidth: 2,
  spacing: 1,
  logScale: false,      // 幅度对数压缩（降低峰值压制）
  freqLogScale: true,   // 频率轴对数分布（拉伸低频）
)
```
- 若感觉能量集中在左侧，可尝试 `freqLogScale: false` 改为线性频率轴，或开启 `logScale: true` 调整动态范围。

## 架构速览
- Flutter UI：`WaveformView`/`SpectrumView` 自定义绘制与交互，`AudioController` 管状态与命令。
- Flutter 插件：`MethodChannel`/`EventChannel` 校验参数、映射错误码，串接平台桥接。
- 平台桥接：最小化适配（权限/AudioSession/AudioFocus），调用共用的 C/C++ 核心。
- C/C++ 核心：平台解码输出 PCM 后进入环形缓冲 → 回放线程；旁路分支做 FFT/DSP 并节流推送（当前解码为桩实现，真实解码在平台层）。
- 数据流：解码线程写缓冲，回放线程读缓冲并驱动时钟；FFT 线程复用 PCM 分帧；Dart 按节流帧率接收并绘制。

## 集成与构建
1) 环境：Flutter 3.x（稳定版）、Xcode 15+（iOS），Android SDK 34+、NDK r26、CMake（随 Android SDK 安装）。  
2) 依赖获取：在你的工程中添加 `soundwave_player`（本仓库可通过 path 依赖：`soundwave_player/`，Android 默认编译 JNI KissFFT）。  
3) iOS：`pod install` 由 Flutter 生成；确保已接受 Xcode 许可并配置开发者证书。  
4) Android：使用 Android Studio / `flutter build apk`，确保 NDK/CMake 路径在 ANDROID_SDK 内。  
5) 示例运行：`cd soundwave_player/example && flutter run`（真机或模拟器）。

## 插件 API 快览
- `init(SoundwaveConfig config)`：采样率、缓冲大小、通道数、可视化节流配置。
- `load(String source)`：`file://` / `http(s)://`；可选自定义 headers（后续 PR 补充）。
- `play()` / `pause()` / `stop()` / `seek(Duration)`：基础控制。
- 事件流：  
  - `states` (`Stream<AudioState>`): 播放状态、缓冲、错误、进度。  
  - `pcmBuffer` (`Stream<PcmFrame>`): 抽稀后的 PCM 分帧（UI 用于波形）。  
  - `spectrumBuffer` (`Stream<SpectrumFrame>`): 频谱数据（已包含窗口大小/bin 宽度）。
- 示例用法：
```dart
final controller = AudioController();
await controller.init(const SoundwaveConfig(sampleRate: 44100, bufferSize: 2048, channels: 2));
await controller.load('file:///tmp/sample.mp3');
await controller.play();
// UI 侧订阅 controller.states / pcmBuffer / spectrumBuffer 渲染。
```

### 可视化后门（测试用）
- 默认关闭；在测试/调试环境显式开启：`enableVisualizationBackdoor: true`，并在 UI 手势/隐藏开关中调用 `setVisualizationEnabled(true/false)`。
- 示例：Demo 页面长按 AppBar 切换后门开关，关闭时缓冲静音丢弃事件，避免影响导出/实时链路；不建议在生产环境开启。

## 数据导出与校验
- 开启导出：在 `SoundwaveConfig.export` 配置目录/前缀和开关，默认关闭。例如：
```dart
await controller.init(SoundwaveConfig(
  sampleRate: 44100,
  bufferSize: 2048,
  channels: 2,
  export: const ExportConfig(
    directoryPath: '<app-documents-or-external-files>',
    filePrefix: 'session01',
    enablePcm: true,
    enableSpectrum: true,
    enableDebugLog: true, // 可选，输出事件 JSONL 供校验
  ),
));
```
- 产物：`<prefix>_pcm.wav`（float32/stereo/44.1kHz）、`<prefix>_spectrum.csv`、`<prefix>_spectrum.jsonl`，若开启 debug 则有 `<prefix>_events.jsonl`。
- PC 校验：使用 `tools/validate_export.py --wav ... --csv ... --jsonl ... --events <prefix>_events.jsonl`，对比导出文件与实时事件的一致性。

## 目录结构
- `soundwave_player/`：Flutter 插件与示例。
- `native/`：C/C++ 音频核心（环形缓冲/播放线程/FFT）。
- `docs/stories/<version>/`：迭代故事与任务记录（现有 0.0.1：`docs/stories/0.0.1/`）。
- `DESIGN.md`：概要设计（架构/时序/交互图）。

## 可视化配置要点
- 波形：`WaveformStreamView` 支持背景/颜色/线宽；大文件场景建议适度调高抽稀与节流 FPS（降低跨平台开销）。
- 频谱：`SpectrumStyle` 可切换对数/线性频率轴，`logScale` 控制幅度压缩；`barWidth`/`spacing` 平衡分辨率与性能。
- 节流：在 `SoundwaveConfig` 中设置推送 FPS / 单帧样本数；UI 若有掉帧，可降低 FPS 或增大批量。

## 测试与质量
- Dart 静态检查：`flutter analyze`.
- 插件/示例测试：`flutter test`（示例与组件单测）。
- 原生侧（若修改 C/C++）：使用 `clang-tidy` / gtest（见 `native/` 说明，后续补充脚本）。
- 手动校验：示例内置测试音频（sine/square/saw/白噪/粉噪/扫频/静音）可比对波形与谱形态。

## 已知限制与路线
- 当前聚焦本地播放与可视化，流式播放 Story 暂缓（见 `CHANGELOG.md`）。
- 弱网/丢包、长时间跑分、录音通路尚未覆盖。
- 后续里程碑：流式播放 → 频谱交互/缩放 → 性能与稳定性回归（详见 `docs/stories/<version>/`）。

## 贡献
- 欢迎提交 Issue/PR，遵循 TDD：先写失败用例再实现。
- 代码格式：`flutter format`/`clang-format`；提交前跑通相关测试。
- 讨论与设计：参见 `docs/design/0.0.2/TECH_DESIGN_0.0.2.md`、`docs/prd/0.0.2/PRD.md`、`AGENTS.md` 保持上下文一致。

## License
- Apache-2.0，详见仓库 `LICENSE`。
- 第三方依赖与版权信息见 `NOTICE` 与 `DEPENDENCIES`（ExoPlayer Apache、KissFFT BSD、Apple vDSP 专有）。
