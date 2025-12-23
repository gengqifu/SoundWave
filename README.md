# SoundWave
移动端音频播放 + 实时可视化（波形 / 频谱）的 Flutter 插件与示例。上层播放器负责解码为 PCM，插件负责节流、绘制与跨端桥接。

## 功能
- 播放本地/流式音频（ExoPlayer/AVPlayer），支持播放控制与前后台切换。
- 实时波形渲染：PCM 分帧抽稀绘制，支持背景/颜色/线宽配置。
- 实时频谱渲染：KissFFT（跨 iOS/Android/C++ 唯一路径）+ Hann 窗口；支持对数频率轴/线性频率轴、幅度对数压缩。
- 数据节流：PCM/频谱事件按 FPS 与批次推送，降低 Platform Channel 开销。

## 环境要求
- Flutter >= 3.13（稳定版），Dart SDK 与之匹配。
- iOS：Xcode 15+，iOS 12+ 部署目标，CocoaPods 可用。
- Android：compileSdk 34，minSdk 21，NDK r26（26.1.x）+ CMake（随 Android SDK），Android Studio 电量/音频权限正常。
- 运行示例建议使用真机；频谱性能评估也以真机为准。

## 快速体验（示例）
1) 安装好 Flutter、iOS/Android 依赖。  
2) 安装示例依赖：
```bash
cd soundwave_player/example
flutter pub get
```
3) 运行示例：
```bash
flutter run  # 连接真机/模拟器
```
4) 示例页点击 `Use bundled sample.mp3` → `Init` → `Load` → `Play`，即可看到波形/频谱渲染。

## 在你的项目中集成
1) 在 `pubspec.yaml` 添加依赖（本仓库为 path 依赖示例，可替换为发布源）：
```yaml
dependencies:
  soundwave_player:
    path: soundwave_player
```
2) 运行 `flutter pub get`。
3) iOS：
   - 确认 `platform :ios, '12.0'`（默认符合 podspec）。
   - 首次或依赖更新后执行 `cd ios && pod install`。
   - 若需要播放明文 http 流，配置 `NSAppTransportSecurity` 允许域名或使用 https。
4) Android：
   - 保持 `compileSdkVersion 34`、`minSdkVersion 21`，并确保已安装 NDK r26（Android Studio SDK Manager）。
   - 如需播放 http 流，`AndroidManifest.xml` 的 `application` 节点可设置 `android:usesCleartextTraffic="true"` 或为特定域名配置 network security config。
5) 构建/运行：`flutter run`（或 `flutter build apk/ipa`）验证。

## 最小使用示例
```dart
final controller = AudioController();

Future<void> setup() async {
  await controller.init(const SoundwaveConfig(
    sampleRate: 48000,
    bufferSize: 2048,
    channels: 2,
    pcmMaxFps: 30,          // 可选：波形推送 FPS 限制
    spectrumMaxFps: 30,     // 可选：频谱推送 FPS 限制
  ));
  await controller.load('file:///tmp/sample.mp3'); // 支持 https/file
  controller.states.listen((s) => debugPrint('state=$s'));
  controller.pcmBuffer.listen((f) => debugPrint('pcm seq=${f.sequence}'));
  controller.spectrumBuffer.listen((f) => debugPrint('spectrum bins=${f.bins.length}'));
  await controller.play();
}

@override
void dispose() {
  controller.dispose();
  super.dispose();
}
```
- UI 侧可直接使用 `WaveformStreamView` / `SpectrumStreamView` 绑定上述流。
- 若你自行解码 PCM，可用 `SoundwavePlayer.pushPcmFrame` 推送原始分帧（采样率/通道需与初始化一致）。

## 工作原理
- Flutter UI：`WaveformView`/`SpectrumView` 自绘组件 + 交互；`AudioController` 负责状态聚合、命令封装。
- 平台插件：`MethodChannel`/`EventChannel` 校验参数、映射错误码，桥接平台播放器。
- 平台桥接：ExoPlayer/AVPlayer 负责解码，PCM/状态经桥接传入 C/C++ 核心。
- C/C++ 核心：PCM ingress 校验 → 环形缓冲/节流 → Downmix → Hann 窗口 → KissFFT → 波形/频谱事件回传。
- 线程模型：解码线程写缓冲；回放/可视化线程拉取 PCM、触发 UI 事件；FFT 可与回放同线程或独立，避免在 UI 线程重计算。

## 插件 API 参考
- 初始化：`init(SoundwaveConfig config)`（必填字段：`sampleRate`、`bufferSize`、`channels`；可选节流：`pcmMaxFps`、`pcmFramesPerPush`、`pcmMaxPending`、`spectrumMaxFps`、`spectrumMaxPending`；网络：`connectTimeoutMs`、`readTimeoutMs`、`enableRangeRequests`；播放：`ringBufferMs`；调试：`enableSkiaTracing`）。所有数值必须 >0（pending 类可为 0），否则抛 `ArgumentError`。
- 载入/控制：`load(source, {headers, rangeStart, rangeEnd})`，支持 `file://`/`http(s)://`，range 需满足 `start<=end`；`play`/`pause`/`stop`/`seek(Duration)` 基础控制。
- 事件流：
  - `states` → `AudioState{position,duration,bufferedPosition?,isPlaying,isBuffering,levels?,spectrum?,error?}`。
  - `pcmBuffer` → `PcmFrame{sequence,timestampMs,samples}`，samples 为交错 float。
  - `spectrumBuffer` → `SpectrumFrame{sequence,timestampMs,bins,binHz}`，bins 为幅度/功率谱。
- 订阅控制：`subscribeWaveform` / `unsubscribeWaveform`、`subscribeSpectrum` / `unsubscribeSpectrum` 控制后台事件推送。
- 推送 PCM（自解码场景）：`pushPcmFrame(PcmInputFrame)`，需提供 `sampleRate`、`channels`、`timestampMs`、`sequence`、`samples`（长度可被通道数整除）。
- 错误码映射（`SoundwaveException.code`）：`invalid_format`、`buffer_overflow`、`fft_error`、`network_error`、`playback_error`、`timeout`，message 提供可读中文提示。

## 可视化配置要点
```dart
const SpectrumStyle(
  barColor: Colors.cyan,
  background: Colors.black,
  barWidth: 2,
  spacing: 1,
  logScale: false,      // 幅度对数压缩（降低峰值压制）
  freqLogScale: true,   // 频率轴对数分布（拉伸低频）
);
```
- 若能量过于集中在左侧，可将 `freqLogScale` 设为 false（线性轴）或开启 `logScale` 调整动态范围。
- 波形：`WaveformStreamView` 支持背景/颜色/线宽；大文件或高 FPS 场景可提升抽稀（`pcmFramesPerPush`）或降低 `pcmMaxFps`。
- 节流：在 `SoundwaveConfig` 设置推送 FPS / 单帧样本数；UI 掉帧可降低 FPS 或增大批量。

## 测试与排障
- 基础检查：`flutter analyze`、`flutter test`（插件与示例）。
- 示例验证：`cd soundwave_player/example && flutter run`，播放内置测试音频（sine/square/saw/白噪/粉噪/扫频/静音）核对波形/频谱。
- iOS 常见问题：`pod install` 失败→更新 CocoaPods 源（`pod repo update`）；编译失败→确认已接受 Xcode 许可并使用真机或匹配的模拟器。
- Android 常见问题：NDK/CMake 未安装→通过 Android Studio SDK Manager 安装 r26；播放 http 流 失败→检查 `usesCleartextTraffic` 或改用 https。

## 已知限制与路线
- 目前聚焦本地播放与可视化，流式播放/弱网与长时间跑分尚未完备（见 `CHANGELOG.md`、`docs/stories/<version>/`）。
- 录音通路未覆盖；频谱交互/缩放、弱网策略在后续里程碑迭代。

## 目录结构
- `soundwave_player/`：Flutter 插件与示例。
- `native/`：C/C++ 核心（PCM ingress/节流/KissFFT 等）。
- `docs/stories/<version>/`：迭代故事与任务记录（现有 0.0.1、0.0.2）。
- `docs/design/<version>/`：概要设计（架构/时序/交互图）。

## 贡献
- 欢迎提交 Issue/PR，遵循 TDD：先写失败用例再实现。
- 提交前格式化并跑通相关测试：`flutter format`/`clang-format`/`flutter analyze`/`flutter test`。
- 讨论与设计：参见 `docs/design/0.0.2/TECH_DESIGN_0.0.2.md`、`docs/prd/0.0.2/PRD.md`、`AGENTS.md`。

## 许可
- 主许可证：Apache License 2.0。
- 第三方依赖（摘要，详见 `NOTICE` / `DEPENDENCIES`）：
  - Flutter SDK / Dart 包（BSD-3-Clause）。
  - AndroidX / Media3 ExoPlayer、AppCompat、Material、Kotlin stdlib（Apache-2.0）。
  - KissFFT（BSD-3-Clause）。
  - iOS 平台 AVFoundation/AVAudioEngine（Apple 平台 SDK 条款）。
