# soundwave_player

SoundWave Flutter 插件，桥接移动端音频播放与实时可视化（时域波形、频谱）。当前聚焦本地播放可视化（Story09/11），流式播放/弱网策略待 Story10 恢复。

## 适用场景与现状
- 适用：Flutter 应用需要播放本地或流式音频，并在 UI 中显示波形/频谱；或宿主自行解码 PCM 后推送给插件做可视化。
- 现状：本地播放可视化可用；流式播放/弱网/后台 Service 尚未实现；错误码与节流参数已定义，接口稳定性在演进。

## 环境要求
- Flutter >= 3.13（稳定版），Dart 与之匹配。
- iOS：Xcode 15+，部署目标 12+。需执行 `pod install`，如需后台播放需开启 Background Modes (Audio)。
- Android：compileSdk 34、minSdk 21，使用 AndroidX / Media3；建议安装 NDK r26 以匹配示例/CI 环境。

## 安装与集成
在你的工程 `pubspec.yaml` 中添加依赖（可改为 path 依赖）：
```yaml
dependencies:
  soundwave_player:
    git: https://github.com/gengqifu/SoundWave.git
    # 或
    # path: ../soundwave_player
```
然后执行：
```bash
flutter pub get
```
iOS：进入 `ios/` 执行 `pod install`，接受 Xcode 许可。  
Android：确保使用 AndroidX，若播放 http 流需在 `AndroidManifest.xml` 配置 `usesCleartextTraffic="true"` 或 network security config。

## 运行示例
```bash
cd soundwave_player/example
flutter pub get
flutter run  # 真机或模拟器
```
示例页面可点击 “Use bundled sample.mp3” → `Init` → `Load` → `Play` 体验波形/频谱；也可选择内置测试音频（正弦/方波/噪声/扫频等）。

## 快速开始（Flutter）
使用内置 `AudioController` 聚合状态与流：
```dart
import 'package:soundwave_player/soundwave_player.dart';

final controller = AudioController();

Future<void> setup() async {
  await controller.init(const SoundwaveConfig(
    sampleRate: 48000,
    bufferSize: 2048,
    channels: 2,
    pcmMaxFps: 30,      // 可选：波形事件节流
    spectrumMaxFps: 30, // 可选：频谱事件节流
  ));
  await controller.load('file:///tmp/sample.mp3'); // 支持 file/http/https
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
- UI 侧可直接使用 `WaveformStreamView` / `SpectrumStreamView` 绑定对应流。
- 若你自行解码 PCM，可调用 `SoundwavePlayer.pushPcmFrame` 推送交错 PCM 分帧，然后订阅波形/频谱事件。

## API 速览
- 初始化：`init(SoundwaveConfig config)`（必填：`sampleRate`、`bufferSize`、`channels`；可选节流：`pcmMaxFps`、`pcmFramesPerPush`、`pcmMaxPending`、`spectrumMaxFps`、`spectrumMaxPending`；网络：`connectTimeoutMs`、`readTimeoutMs`、`enableRangeRequests`；播放：`ringBufferMs`；调试：`enableSkiaTracing`）。数值需 >0（pending 可为 0），不合法抛 `ArgumentError`。
- 控制：`load(source, {headers, rangeStart, rangeEnd})`、`play()`、`pause()`、`stop()`、`seek(Duration)`。source 支持 `file://` / `http(s)://` / 相对路径（视平台而定），range 需满足 `start<=end`。
- 事件流：
  - `states` → `AudioState{position,duration,bufferedPosition?,isPlaying,isBuffering,levels?,spectrum?,error?}`。
  - `pcmBuffer` → `PcmFrame{sequence,timestampMs,samples}`（交错 float）。
  - `spectrumBuffer` → `SpectrumFrame{sequence,timestampMs,bins,binHz}`。
- 订阅控制：`subscribeWaveform` / `unsubscribeWaveform`、`subscribeSpectrum` / `unsubscribeSpectrum` 控制后台推送。
- 错误码映射（`SoundwaveException.code`）：`invalid_format`、`buffer_overflow`、`fft_error`、`network_error`、`playback_error`、`timeout`，message 提供中文提示。
- 约束：未 `init` 调用会抛 `StateError`；`seek` 不能为负；`pushPcmFrame` 需提供非空 samples，长度可被 channels 整除。

## 数据流与线程模型
- Flutter 调用 MethodChannel (`soundwave_player`) 发送控制命令，EventChannel (`state`/`pcm`/`spectrum`) 接收事件。
- 平台侧使用 ExoPlayer/AVPlayer 解码（或上层自解码），PCM 进入 C/C++ 核心做节流/FFT，下发波形/频谱事件供 Dart 绘制。
- UI 绘制在 Flutter 侧，核心尽量在平台线程/后台线程完成，减少 UI 卡顿；波形/频谱事件可通过节流参数控制频率。

## 可视化样式
```dart
const SpectrumStyle(
  barColor: Colors.cyan,
  background: Colors.black,
  barWidth: 2,
  spacing: 1,
  logScale: true,     // 幅度对数压缩
  freqLogScale: true, // 频率轴对数分布
);
```
- 低频占比过大可将 `freqLogScale` 设为 false；如存在峰值淹没，可调整 `logScale` 或增大 `barWidth`/`spacing` 以减负载。

## 常见问题与排障
- iOS `pod install` 失败：更新 CocoaPods 源（`pod repo update`），确认 Xcode 许可已接受；真机需配置签名。
- Android 播放 http 失败：Manifest 开启 `usesCleartextTraffic` 或改用 https；确保使用 AndroidX。
- 无波形/频谱：确认已调用 `subscribeWaveform`/`subscribeSpectrum`，且源音频有内容；检查节流参数是否过低。
- 性能不足：降低 `pcmMaxFps`/`spectrumMaxFps` 或增大 `pcmFramesPerPush`；UI 端减少每帧绘制量。

## 开发与测试
- 格式化：`dart format lib test example/lib`
- 静态检查：`flutter analyze`
- 单测：`flutter test`

## 手工验收要点
- 使用示例内置音频：正弦峰值单峰，方波/锯齿谐波递减，白噪谱平坦、粉噪高频衰减，扫频主峰平滑移动，静音无显著能量。
- 前后台切换后播放/可视化应保持；错误码应映射为中文提示。
