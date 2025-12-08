# Android Visualization Core (Native-only)

目标：提供不依赖 Flutter 的 Android AAR（`com.soundwave:visualization-core`），封装 PCM 采集/节流、FFT（KissFFT）、导出等能力，供上层 App 或 Flutter 插件以二进制/源码形式依赖。

当前状态（骨架）：
- 目录：`native/android-visualization/`
- Gradle library module（无 Flutter 依赖），占位 Kotlin API `VisualizationCore`。
- Maven Publish 已配置（groupId `com.soundwave`, artifactId `visualization-core`, version `0.0.2-native-SNAPSHOT` 可调整），默认发布到本地 `build/m2-local`（可通过 `-PsoundwaveRepoDir` 覆写）。

后续工作：
- 将 `native/core` C++ 静态库接入（CMake），暴露 JNI 接口（init/load/play/pause/seek、PCM/谱回调、导出开关）。
- 增加 gtest/仪表测试与发布 smoke（AAR + 简易原生 app 验收）。
- 对齐 Story08 测试计划 `native/core/Testing/TEST_PLAN_NATIVE_PACKAGING.md`。
