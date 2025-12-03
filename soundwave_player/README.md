# soundwave_player

SoundWave Flutter 插件，用于桥接移动端音频播放/可视化能力（时域波形、频谱）。当前支持本地播放可视化（Story09/11），流式播放待 Story10 恢复。

## 安装

```yaml
dependencies:
  soundwave_player:
    git: https://github.com/gengqifu/SoundWave.git
```

## 快速开始（本地播放）

```dart
import 'package:soundwave_player/soundwave_player.dart';

final player = SoundwavePlayer();

Future<void> init() async {
  await player.init(const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2));
  await player.load('file:///tmp/sample.mp3');
  await player.play();
}

void listen() {
  player.stateEvents.listen((event) {
    // 处理播放/缓冲/错误事件
  });
  player.pcmEvents.listen((pcm) {
    // 处理可视化 PCM 帧
  });
  player.spectrumEvents.listen((spectrum) {
    // 处理频谱数据
  });
}
```

### 约束与注意
- 初始化只允许一次；未 init 的调用会抛 `StateError`。
- 参数校验：空 source、负 `seek`、非正 sampleRate/bufferSize/channels 会抛 `ArgumentError`。
- 流式播放/弱网策略尚未实现（Story10 暂缓），当前聚焦本地播放。

### 可视化样式
```dart
const SpectrumStyle(
  barColor: Colors.cyan,
  background: Colors.black,
  barWidth: 2,
  spacing: 1,
  logScale: true,      // 幅度对数压缩，防止峰值淹没细节
  freqLogScale: true,  // 频率轴对数分布，低频更宽
);
```
- 低频占比过大时，可将 `freqLogScale` 设为 `false` 变为线性频率轴，或调小 `logScale` 影响。

## 开发

- 格式化：`HOME=/your/writable/home dart format lib test example/lib`
- 静态检查：`HOME=/your/writable/home flutter analyze`
- 单元测试：`HOME=/your/writable/home flutter test`

## Demo

- 验收清单：见 `docs/demo_acceptance.md`（本地播放、波形/频谱刷新、前后台切换）。
- 自动化冒烟占位：`example/integration_test/demo_smoke_test.dart`（待 UI 实现后补充）。

## 平台配置（前后台/后台播放）

- iOS：宿主 App 需在 Xcode 中开启 Background Modes（Audio），`Info.plist` 增加 `UIBackgroundModes = audio`。插件已配置 `AVAudioSessionCategoryPlayback` 并监听中断/路由变更，后台播放权限需由宿主工程启用。
- iOS 隐私：`ios/Resources/PrivacyInfo.xcprivacy` 已声明音频数据访问及必要 API 访问（时间戳、UserDefaults），如有自定义用途请补充。
- Android：目前未启用通知栏/前台 Service，如需后台播放请在宿主应用添加前台 Service 与通知渠道，并配置 `android.permission.FOREGROUND_SERVICE`/`INTERNET`。

> 使用本仓库的建议 HOME（避免 lockfile 权限问题）：`/Users/gengqifu/git/ext/SoundWave/.home`
