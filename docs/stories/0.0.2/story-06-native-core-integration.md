# Story 06：原生核心接入与功能完备

## 目标
- 将 Story02/03/04 涉及的核心能力（FFT/PCM 节流/导出/可视化回调）完整封装进原生可发布包：Android AAR、iOS XCFramework，彻底去除 Flutter 依赖。
- 确保跨端参数/归一化/线程模型一致，能被 Demo 及上层插件直接集成。

## 测试优先（TDD）
- ◻️ [1] 频谱一致性：单频/双频/白噪/扫频基线（Hann、nfft=1024、归一化 2/(N*E_window)），Android（KissFFT）与 iOS（vDSP）误差 < 1e-3。
- ◻️ [2] 回调/导出通路：PCM 节流、频谱回调、数据导出在原生层闭环验证（含线程安全），有 gtest/仪表或真机用例。

## 开发任务
- ◻️ [3] Android AAR：CMake 接入 `native/core`，JNI 暴露 init/load/play/pause/stop/seek、PCM/谱回调、导出控制；整理线程/错误映射；保持无 Flutter 依赖。发布到本地 maven 验收。
- ◻️ [4] iOS XCFramework：以 vDSP 为默认 FFT，接入 PCM 节流/导出/回调；必要时桥接 `native/core` C++。构建 arm64 + 模拟器 XCFramework，Podspec/SPM 校验通过。
- ◻️ [5] 跨端一致性：统一参数/归一化/窗口，准备对照矢量并记录误差；更新对齐报告。
- ◻️ [6] 发布/脚本：更新 `tools/release/build_native_packages.sh` 支持新产物（含校验/路径），生成本地 maven + XCFramework。

## 完成标准（DoD）
- ◻️ [7] 原生 AAR/XCFramework 含真实功能（FFT/PCM/导出/可视化回调），本地或私有仓库可发布并通过校验。
- ◻️ [8] 跨端 FFT 对齐报告更新，误差在容差内，测试记录齐全。
- ◻️ [9] 提供集成指南：插件/Demo 如何切换到新产物（Debug 本地、Release 仓库）。***
