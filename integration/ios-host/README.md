## iOS Host (纯原生示例思路)

- 产物：`soundwave_player/build/ios_framework/Release/SoundwaveCore.xcframework`（无 Flutter 依赖）。
- 资源：`Resources/` 下已拷贝 `soundwave_player/example/assets/audio/` 里的测试音频（wav/mp3）。
- 示例代码：`Sources/SpectrumHost.swift` 展示如何用 `AVAudioEngine` 播放 bundle 音频并调用 `SoundwaveCore.SpectrumEngine` 计算频谱，可通过 `fileName` 切换播放文件（默认 `sample.wav`）。

### 集成步骤（手工创建最小工程）
1. 在 Xcode 中新建 iOS App（Swift/UIKit 或 SwiftUI 均可），最低 iOS 12。
2. 将 `SoundwaveCore.xcframework` 拖入工程（Embed & Sign）。
3. 将 `Resources/sample.wav` 拖入工程（Target Membership 勾选）。
4. 拖入 `Sources/SpectrumHost.swift`，在 `AppDelegate`/`SceneDelegate` 或 ViewModel 中实例化 `SpectrumHost`（可设置 `fileName` 为 `sine_1k.wav` 等），并调用 `start()`。
5. 运行后控制台会输出频谱 bins 数和前三个幅度示例；如需替换音频，可改换 bundle 资源或调整 `fileName`。

> 说明：此目录未生成完整 `.xcodeproj`，便于在现有工程直接拷贝代码/资源快速验证。若需独立工程，可按上述步骤在 `integration/ios-host` 内创建一个 Xcode 项目并复用这些文件。
