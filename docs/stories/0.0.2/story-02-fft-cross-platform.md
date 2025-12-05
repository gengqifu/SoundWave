# Story 02：FFT 替换与跨端对齐

## 目标
- Android 使用 KissFFT（JNI），iOS 默认 vDSP（提供可选 KissFFT），统一窗口/归一化/输出格式，跨端谱差异 < 1e-3。

## 测试优先（TDD）
- ✖️ [1] 频点正确性：单频/双频/白噪测试在 Android KissFFT、iOS vDSP/KissFFT 上对齐，容差 < 1e-3。
- ✖️ [2] 门禁：`flutter test` 覆盖 FFT 事件解析；Native 单测/集成测（如 gtest/Instrumentation）通过。

## 开发任务
- ✖️ [3] Android 接入 JNI + KissFFT，移除 Kotlin FFT 主路径。
- ✖️ [4] iOS 保持 vDSP 默认，增加 KissFFT 可选开关，接口与归一化对齐。
- ✖️ [5] 跨端一致性测试与阈值校验，确保窗口、nfft、overlap、归一化一致。

## 完成标准（DoD）
- ✖️ [6] 跨端 FFT 对齐测试通过，谱差异在容差内。
- ✖️ [7] 相关单测/集成测/构建门禁通过。
- ✖️ [8] 文档更新 FFT 选型与开关说明。***
