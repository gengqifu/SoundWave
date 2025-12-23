# soundwave_player 示例

演示 SoundWave Flutter 插件的本地播放与可视化（波形/频谱），方便新用户上手与验收。

## 环境要求
- Flutter >= 3.13；已配置 iOS/Android 开发环境。
- 真机或模拟器均可，性能/音频行为以真机为准。

## 运行
```bash
cd soundwave_player/example
flutter pub get
flutter run  # 连接真机/模拟器
```
示例默认使用 48 kHz、2048 buffer、立体声配置。可通过界面输入本地/网络音频地址或使用内置资产。

## 界面与操作
- `Use bundled sample.mp3`：拷贝内置 mp3 到临时目录并填入输入框。
- `Init` → `Load` → `Play`：初始化、加载并播放，页面下方实时显示波形/频谱。
- `Pause` / `Stop` / `Seek`：基础播放控制。
- `Push PCM (sine_1k/square_1k)`：解析内置 WAV 为 PCM，调用 `pushPcmFrame` 推送，演示波形/频谱链路；会按初始化采样率自动重采样。
- 页面右上角显示可视化累计帧数/丢弃数，便于观察节流与背压。

## 可视化说明
- 波形：抽稀后绘制，背景黑、线色浅蓝，默认节流约 30fps。
- 频谱：Hann 窗口 + KissFFT；默认对数频率轴（低频更宽），可在代码中切换 `SpectrumStyle(freqLogScale: false)` 改为线性轴。

## 预期行为（自测参考）
- 正弦：波形平滑，频谱单峰；方波/锯齿：多谐波递减；噪声：谱平坦或高频衰减；扫频：主峰平滑从低到高；静音：无显著能量。

## 常见问题
- 未先 `Init` 会抛 `StateError`：按流程点击 `Init`。
- 加载失败：检查路径/协议（file/http/https），或使用 `Use bundled sample.mp3`。
- 无波形/频谱：确保已订阅（示例默认），源音频非空；节流参数过低可能看不到更新。
