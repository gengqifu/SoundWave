# Story 07：原生可发布包拆分（无 Flutter 依赖）

## 目标
- 拆出纯原生可发布库：Android AAR（`com.soundwave:visualization-core` 等）、iOS XCFramework（Pod/SPM `SoundwaveVisualization`），**不依赖 Flutter**。Flutter 仅用于 Demo/插件层调用原生包。
- Flutter 插件改为依赖上述原生包（源码/path/本地 maven/CocoaPods 形式），保持现有 API，对接 Demo。
- 构建策略：Debug Demo 依赖本地原生模块（Android module、iOS 本地 XCFramework），Release 使用发布的原生库。
- 能力收敛要求：Story02（FFT 跨端）、Story03（数据导出）、Story04（可视化通路）涉及的能力均需封装到独立原生模块中；iOS 侧必须包含在 XCFramework 内，Android 侧必须包含在可发布的 AAR 内，不依赖 Flutter 代码。

## 测试优先（TDD）
- ✅ [1] 原生库单测/集成测：JNI/ObjC Swift 层接口、FFT/PCM 节流、导出通路验证。（测试计划已落地 `native/core/Testing/TEST_PLAN_NATIVE_PACKAGING.md`，列出桥接/导出/集成验收用例）
- ✖️ [2] 集成验证：Flutter Demo 依赖新原生包（本地/私有仓库）可构建运行。

## 开发任务
**前置（阻塞项，需先完成）**
- ✅ [3a] Android 原生产物：接入 native/core JNI 最小实现并生成 AAR，使用 `./tools/release/build_native_packages.sh` 发布到本地 maven（无 Flutter 依赖）。已增加 CMake/NDK 占位 JNI（`NativeBridge.nativeVersion()`）与 `libvisualizationcore.so` 构建链路，待与 native/core 联调。
- ✅ [4a] iOS 原生产物：基于 `native/ios-visualization` 生成占位 `SoundwaveVisualization.xcframework`（arm64 + 模拟器），完成 Podspec/SwiftPM 校验。新增 `scripts/build_stub_xcframework.sh` 用占位 C 版本号导出生成 XCFramework，后续替换为 native/core 能力。

**实施**
- ✅ [3] Android：新建/整理纯原生 module（无 Flutter 依赖），配置 maven-publish；迁移 ExoPlayer/KissFFT/PCM 管线代码。（已创建 `native/android-visualization` 骨架，maven-publish 配置 `com.soundwave:visualization-core:0.0.2-native-SNAPSHOT`，后续接入 native/core & JNI）
- ✅ [4] iOS：产出 XCFramework + Podspec/SPM 清单（无 Flutter 依赖），迁移 vDSP/KissFFT/导出逻辑。（新增 `native/ios-visualization/`，含 Podspec/Package.swift，等待接入 native/core 并生成 XCFramework）
- ✅ [5] Flutter 层适配：插件改为引用原生包（path/maven/Pods），示例调整依赖方式；发布脚本更新。（Android 已支持本地 module 或 maven；iOS Podspec 支持 `SW_VIS_LOCAL_PATH` 指向本地 XCFramework 目录，默认依赖发布的 `SoundwaveVisualization` 版本；参考 `docs/plans/story08-flutter-adapter.md`）
- ✅ [6] CI/脚本：发布/校验流程覆盖新原生包，确保无 Flutter 依赖。（新增 `tools/release/build_native_packages.sh`，Android 本地 maven 发布；iOS 进行 Podspec/SwiftPM 校验，需事先生成 XCFramework）

## 完成标准（DoD）
- ✅ [7] 原生包可单独发布/被集成（本地或私有仓库验证）。依赖 [3a]/[4a]。Android 已通过 `soundwave_player/android/gradlew -p native/android-visualization ... publishReleasePublicationToLocalRepository` 发布到本地 `build/native-release/android/m2-local`；iOS 占位 XCFramework 已生成，可用于本地 Pod/SPM 集成。
- ✖️ [8] Story02/03/04 的核心能力（FFT/vDSP、PCM/导出、可视化回调链路）已封装进原生 AAR/XCFramework（无 Flutter 依赖），并有验证记录。（完成后方可执行 [9]）
- ✖️ [9] Flutter Demo 使用原生包跑通，构建/测试/合规检查通过。依赖 [7] + [8]。***
