## Integration hosts

### Android
- 路径：`integration/android-host`
- 依赖：使用已构建的 `core-release.aar`、`adapter-release.aar`（纯原生，无 Flutter）。`soundwave_player-release.aar` 仅供 Flutter 插件壳，不在宿主验证中使用。
- 资源：`app/src/main/assets/sample.wav`（离线 2s 440Hz WAV）。
- 构建/运行：
  1) 先在根目录执行 `cd soundwave_player/android && GRADLE_OPTS='-Dorg.gradle.native=false' ~/.gradle/wrapper/dists/gradle-8.1.1-bin/gradle-8.1.1/bin/gradle assembleRelease` 生成 AAR。
  2) 打开 `integration/android-host`，使用同一 Gradle 分发构建：`~/.gradle/wrapper/dists/gradle-8.1.1-bin/gradle-8.1.1/bin/gradle :app:assembleDebug`
  3) 示例默认播放本地 WAV 并通过 `PcmTapProcessor` + `SpectrumEngine` 拉取 PCM/频谱；如需替换音频，更新 `assets/sample.wav`。

### iOS
- 目录：`integration/ios-host`（包含示例代码与资源，未生成 `.xcodeproj`，便于拷贝到现有工程）。
- 产物：`soundwave_player/build/ios_framework/Release/SoundwaveCore.xcframework`（纯原生，无 Flutter）。
- 资源：`Resources/sample.wav`；示例代码 `Sources/SpectrumHost.swift` 使用 `AVAudioEngine` 播放并调用 `SpectrumEngine` 计算频谱。
- 使用：在任意 iOS App 工程中按 README 步骤拖入 xcframework、资源和代码后运行，控制台会输出频谱示例。
