# SoundWave
移动端音频播放 + 实时可视化（波形 / 频谱）的 Flutter 插件与示例。

## 功能
- 播放本地/流式音频（ExoPlayer/AVPlayer），支持播放控制与前后台切换。
- 实时波形渲染：PCM 分帧抽稀绘制，支持背景/颜色/线宽配置。
- 实时频谱渲染：Hann 窗口 + FFT，支持对数频率轴（默认）或线性轴、幅度压缩。
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

## 目录结构
- `soundwave_player/`：Flutter 插件与示例。
- `native/`：C/C++ 音频核心（FFmpeg/FFT 等）。
- `stories/`：迭代故事与任务记录。
- `DESIGN.md`：概要设计（架构/时序/交互图）。

## 状态
- 当前版本聚焦本地播放与可视化，流式播放 Story 暂缓中（详见 CHANGELOG）。
