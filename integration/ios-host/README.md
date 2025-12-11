## iOS Host (纯原生示例思路)

- 产物：`soundwave_player/ios/core/build/SoundwaveCore.xcframework`（纯原生，无 Flutter）。
- 资源：`Resources/` 下已拷贝 `soundwave_player/example/assets/audio/` 里的测试音频（wav/mp3）。
- 示例代码：`Sources/SpectrumHost.swift` 展示如何用 `AVAudioEngine` 播放 bundle 音频并调用 `SoundwaveCore.SpectrumEngine` 计算频谱，可通过 `fileName` 切换播放文件（默认 `sample.wav`）。

### 现成示例工程（使用 XcodeGen 生成）
目录包含 `project.yml`，可用 XcodeGen 快速生成 `.xcodeproj`：
```bash
cd integration/ios-host
xcodegen generate
open HostApp.xcodeproj
```
如未安装 XcodeGen：`brew install xcodegen`。

工程说明：
- Target: `HostApp`（SwiftUI，最低 iOS 14）
- 依赖：`../../soundwave_player/ios/core/build/SoundwaveCore.xcframework`
- 资源：`Resources/` 下音频自动打包
- 代码：`Sources/AppMain.swift`、`ContentView.swift`、`SpectrumHost.swift`

运行：选择模拟器或真机 Run，默认播放 `sample.wav`，控制台输出频谱 bins/top3；可在 `AppMain.swift` 中修改 `fileName` 选择其他音频。
