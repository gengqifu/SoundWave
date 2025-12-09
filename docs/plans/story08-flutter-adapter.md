# Story08 Flutter 适配方案（原生包）

目标：Flutter 插件/示例依赖纯原生包（无 Flutter 依赖的 AAR/XCFramework），便于分发与复用。

## Android 适配方案
- 依赖配置：
  - 在 `soundwave_player/android/build.gradle` 中增加可配置仓库（如 `-PsoundwaveRepoDir` 或私有 Maven URL），并依赖坐标 `com.soundwave:visualization-core:<ver>`.
  - CI/发布脚本：先运行 `native/android-visualization` 的 `publish`（本地 m2），再构建 Flutter 插件/示例。
- 源码联调：
  - 提供 `settings.gradle` include `native/android-visualization` 方式，供本地开发不依赖发布仓库。
- 验收：
  - `flutter build aar`/`flutter test` 时可拉到 AAR。
  - 示例 App 播放/波形/谱/导出正常。

## iOS 适配方案
- 依赖配置：
  - `soundwave_player/ios/soundwave_player.podspec` 引用 `SoundwaveVisualization` Pod（私有 spec repo 或本地 path），或 SPM 二进制包。
  - 在发布脚本中先生成 `SoundwaveVisualization.xcframework` + Podspec/Package.swift，并放入可访问路径。
- 验收：
  - `pod lib lint soundwave_player.podspec` / `flutter build ios-framework` 时能解析 `SoundwaveVisualization`。
  - 示例 App 播放/波形/谱/导出正常。

## Flutter 层调整
- 仅做平台通道桥接：删除/屏蔽插件侧原生实现，调用原生 AAR/XCFramework 提供的 JNI/ObjC API。
- 配置切换：
  - 开发模式：使用本地 path（include module / local Pod）。
  - 发布/CI：使用 maven/私有 Pod/二进制包。

## 脚本与 CI
- 扩展 `tools/release/build_release.sh`：
  1) 构建 `native/android-visualization` 并发布到本地 m2。
  2) 构建 `native/ios-visualization` XCFramework，生成 Podspec/Package.swift。
  3) 构建 Flutter 插件/示例（依赖上一步产物）并 smoke。
- CI：新增 Job 跑上述流程（或 dry-run），确保无 Flutter 依赖泄漏到原生包。
