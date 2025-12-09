# Story 08：原生可发布包拆分（无 Flutter 依赖）

## 目标
- 拆出纯原生可发布库：Android AAR（`com.soundwave:visualization-core` 等）、iOS XCFramework（Pod/SPM `SoundwaveVisualization`），**不依赖 Flutter**。Flutter 仅用于 Demo/插件层调用原生包。
- Flutter 插件改为依赖上述原生包（源码/path/本地 maven/CocoaPods 形式），保持现有 API，对接 Demo。

## 测试优先（TDD）
- ✅ [1] 原生库单测/集成测：JNI/ObjC Swift 层接口、FFT/PCM 节流、导出通路验证。（测试计划已落地 `native/core/Testing/TEST_PLAN_NATIVE_PACKAGING.md`，列出桥接/导出/集成验收用例）
- ✖️ [2] 集成验证：Flutter Demo 依赖新原生包（本地/私有仓库）可构建运行。

## 开发任务
- ✅ [3] Android：新建/整理纯原生 module（无 Flutter 依赖），配置 maven-publish；迁移 ExoPlayer/KissFFT/PCM 管线代码。（已创建 `native/android-visualization` 骨架，maven-publish 配置 `com.soundwave:visualization-core:0.0.2-native-SNAPSHOT`，后续接入 native/core & JNI）
- ✅ [4] iOS：产出 XCFramework + Podspec/SPM 清单（无 Flutter 依赖），迁移 vDSP/KissFFT/导出逻辑。（新增 `native/ios-visualization/`，含 Podspec/Package.swift，等待接入 native/core 并生成 XCFramework）
- ✖️ [5] Flutter 层适配：插件改为引用原生包（path/maven/Pods），示例调整依赖方式；发布脚本更新。（适配方案见 `docs/plans/story08-flutter-adapter.md`，开发/调试使用本地原生模块 path 依赖，正式发布改为 maven/Pod/SPM 原生库）
- ✖️ [6] CI/脚本：发布/校验流程覆盖新原生包，确保无 Flutter 依赖。

## 完成标准（DoD）
- ✖️ [7] 原生包可单独发布/被集成（本地或私有仓库验证）。
- ✖️ [8] Flutter Demo 使用原生包跑通，构建/测试/合规检查通过。***
