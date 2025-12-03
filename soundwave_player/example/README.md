# soundwave_player 示例

演示 SoundWave Flutter 插件的本地播放、波形与频谱可视化。

## 运行
```bash
cd soundwave_player/example
flutter pub get
flutter run  # 连接真机/模拟器
```

示例页按钮：
- `Use bundled sample.mp3`：将内置示例音频拷贝到临时目录并填入输入框。
- `Init` → `Load` → `Play`：依次初始化、加载并播放，页面下方会实时显示波形/频谱。
- `Pause`/`Stop`/`Seek`：播放控制。

可视化说明：
- 波形：按帧抽稀绘制，背景黑色，线色浅蓝。
- 频谱：Hann 窗口 + FFT；默认频率轴为对数分布（低频更宽），如需线性可在 `SpectrumStyle(freqLogScale: false)` 调整。

故障排查：
- 未初始化调用会抛异常；确保先点击 `Init`。
- 如提示权限或网络错误，检查源地址是否可访问、真机是否联网。
