# SoundwaveVisualization (iOS Native XCFramework)

目标：提供不依赖 Flutter 的 iOS XCFramework，封装 PCM/FFT/导出等能力，供原生 App 或 Flutter 插件通过 Pod/SPM 依赖。

当前状态（骨架）：
- 目录：`native/ios-visualization/`
- 提供 Podspec (`SoundwaveVisualization.podspec`) 与 SwiftPM 清单 (`Package.swift`)，引用同目录下的 `SoundwaveVisualization.xcframework`（待产出）。
- 新增基于 vDSP 的合成闭环脚本 `scripts/build_vdsp_xcframework.sh`（arm64 设备/模拟器），生成包含 PCM/谱回调的 XCFramework，用于原生闭环验证（默认正弦+Hann+FFT）。产物默认输出到 `native/ios-visualization/build/SoundwaveVisualization.xcframework`，不会污染源码目录；旧的占位脚本 `build_stub_xcframework.sh` 仍保留。

后续工作：
- 将 `native/core` C++ 接入并编译为 XCFramework（含 arm64/x86_64 模拟器），提供 ObjC/Swift API。
- 完善 Podspec/Package.swift 版本号与元数据；补充示例/验证脚本（`pod lib lint` / `swift package diagnose`）。
- 对齐 Story08 测试计划（桥接/导出/FFT/节流验证）。***
