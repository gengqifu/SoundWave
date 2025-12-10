## Integration hosts

### Android
- 路径：`integration/android-host`
- 依赖：使用已构建的 `core-release.aar`、`adapter-release.aar`（纯原生，无 Flutter）。`soundwave_player-release.aar` 仅供 Flutter 插件壳，不在宿主验证中使用。
- 构建/运行：
  1) 先在根目录执行 `cd soundwave_player/android && GRADLE_OPTS='-Dorg.gradle.native=false' ~/.gradle/wrapper/dists/gradle-8.1.1-bin/gradle-8.1.1/bin/gradle assembleRelease` 生成 AAR。
  2) 打开 `integration/android-host`，使用同一 Gradle 分发构建：`~/.gradle/wrapper/dists/gradle-8.1.1-bin/gradle-8.1.1/bin/gradle :app:assembleDebug`
  3) 默认示例播放公开 MP3 链接并通过 `PcmTapProcessor` + `SpectrumEngine` 拉取 PCM/频谱；如需离线测试，替换 `MainActivity` 中的媒体 URL。

### iOS
- 当前产物：`soundwave_player/build/ios_framework/Release/SoundwaveCore.xcframework`（纯原生，无 Flutter）。
- 最小宿主建议：创建一个 iOS App 工程，将 `SoundwaveCore.xcframework` 拖入工程（Embed & Sign），在 Swift 代码中直接调用 `SpectrumEngine`/C API 处理 PCM 数据，验证频谱链路。可复用 KissFFT 已内置的实现。
- 后续可在 `integration/ios-host` 补充示例工程。
