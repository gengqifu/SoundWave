# Story 03：KissFFT 融合与频谱输出

## 目标
- 以 KissFFT 作为唯一 FFT 实现（Android/iOS/C++ 共用），统一窗口参数与归一化，输出频谱事件（含 binHz/原始幅度/归一化幅度）。

## 测试优先（TDD）
- ✖️ [1] FFT 频点单测：单频/双频/白噪信号幅度谱正确，跨平台误差 <1e-3。
- ✖️ [2] 参数覆盖单测：不同 nfft/hop/window 组合输出维度与 binHz 正确。
- ✖️ [3] 性能烟测：连续推流 1 分钟无内存泄漏/明显 CPU 峰值。

## 开发任务
- ✖️ [4] 集成 KissFFT 构建（CMake/Android/iOS），移除 Kotlin FFT 与 vDSP 调用路径。
- ✖️ [5] 实现窗口化/归一化与 downmix，接入 PCM ingress 输出 Spectrum 事件。
- ✖️ [6] 添加跨端对齐测试与性能烟测脚本，更新文档参数说明。

## 完成标准（DoD）
- ✖️ [7] 单测/对齐测试通过，FFT 输出与规格一致；性能烟测通过。
- ✖️ [8] 文档/README/设计更新为 KissFFT 唯一路径，构建不再依赖 vDSP/Kotlin FFT。 
