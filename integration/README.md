## 集成宿主说明
面向不依赖 Flutter 的原生验证工程，用于验证核心解码/频谱链路与可视化组件。

### 前置环境
- Android：JDK 17、Android SDK (compileSdk 34)、Android NDK r26 已安装；可使用真机或 23+ 模拟器。
- iOS：macOS + Xcode 15+，可运行 iOS 15+ 模拟器或真机。
- 仓库根目录：`soundwave_player` 插件工程需可正常构建，用于产出 AAR / xcframework。

### 工作原理速览
- Android 宿主：ExoPlayer 播放 assets 中的 WAV/MP3，`PcmTapProcessor` 从解码链路获取 PCM，交给 `SpectrumEngine` 计算频谱，界面绘制波形/频谱。
- iOS 宿主：`AVAudioEngine + AVAudioPlayerNode` 播放 bundle 音频，`SoundwaveCore.SpectrumEngine` 处理 tap 回调的 PCM，SwiftUI 展示波形/频谱。

### Android 宿主
- 路径：`integration/android-host`
- 依赖产物：`soundwave_player/android` 生成的 `core-release.aar`、`adapter-release.aar`（已在 flatDir 指向默认输出路径）。
- 资源：`app/src/main/assets/` 内置多种测试音频，启动后下拉选择。
- 构建步骤：
  1) 在仓库根执行（生成 AAR）：  
     ```bash
     cd soundwave_player/android
     ./gradlew :core:assembleRelease :adapter:assembleRelease
     ```
  2) 构建宿主 APK：  
     ```bash
     cd ../../integration/android-host
     ./gradlew :app:assembleDebug   # 或 :app:installDebug 安装到已连接设备
     ```
  3) 安装/运行后，选择音频 → Play，界面应显示实时波形与频谱。
- 常见问题
  - 找不到 AAR：确认步骤 1 已生成 `core-release.aar` / `adapter-release.aar`，路径与 `flatDir` 相符。
  - Gradle 版本/JDK 报错：确保 JDK 17，或执行 `./gradlew --version` 检查。
  - 无声/无频谱：确认设备音量、权限正常，或尝试 WAV 资产。

### iOS 宿主
- 路径：`integration/ios-host/host`（含示例工程与资源）。
- 依赖产物：`SoundwaveCore.xcframework`（纯原生）。仓库已内置一份，可在需要时重新生成：  
  ```bash
  cd soundwave_player
  flutter build ios-framework --cocoapods --output=build/ios_framework
  # 生成的 xcframework 位于 build/ios_framework/Release/SoundwaveCore.xcframework
  ```
  将生成的 xcframework 覆盖到 `integration/ios-host/host/SoundwaveCore.xcframework`。
- 运行步骤：
  1) 打开 `integration/ios-host/host/host.xcodeproj`。
  2) 选择模拟器或真机，直接 Run。默认播放 bundle 中的 `sample.wav` 等文件，可在界面切换。
  3) 控制台会输出频谱/状态日志，界面显示波形与频谱。
- 常见问题
  - 架构缺失/签名错误：清理 DerivedData，确保工程使用同一 xcframework；真机需设置有效签名团队。
  - 无频谱数据：检查设备静音开关，或确认 `SoundwaveCore.xcframework` 未被裁剪掉 Simulator/Device slice。
