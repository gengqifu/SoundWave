# Story 02：FFT 替换与跨端对齐

## 目标
- Android 使用 KissFFT（JNI），iOS 默认 vDSP（提供可选 KissFFT），统一窗口/归一化/输出格式，跨端谱差异 < 1e-3。

## 测试优先（TDD）
- ✅ [1] 频点正确性：单频/双频/白噪/扫频在 Android KissFFT、iOS vDSP/KissFFT 上对齐，误差 < 1e-3（支持 L2/最大值度量）。Android 本地单测覆盖单/双频，iOS 归一化对齐（待真机复核）。
- ✖️ [2] 门禁：`flutter test` 覆盖 FFT 事件解析；Native 单测/集成测（gtest/Instrumentation）通过。

## 开发任务
- ✖️ [3] Android 接入 JNI + KissFFT，移除 Kotlin FFT 主路径；定义 JNI 输入/输出（立体声 float PCM，nfft=1024，Hann，归一化公式一致）。
- ✖️ [4] iOS 保持 vDSP 默认，增加 KissFFT 可选开关；窗口/归一化（例如 2/(N*E_window)）与 Android 对齐，可配置 overlap。
- ✖️ [5] 跨端一致性测试与阈值校验：统一窗口/nfft/overlap/归一化，用同一组测试信号（单频/双频/白噪/扫频）做误差评估（L2/最大值）。

## 完成标准（DoD）
- ✖️ [6] 跨端 FFT 对齐测试通过，谱差异在容差内，有测试报告或黄金比对脚本。
- ✖️ [7] 相关单测/集成测/构建门禁通过。
- ✖️ [8] 文档更新 FFT 选型、归一化公式与开关说明。***
