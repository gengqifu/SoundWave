# Story 08：FFT/频谱链路

## 目标
实现窗口化 + FFT（默认使用 KissFFT 后端），推送频谱到 Dart，并完成 `SpectrumView` 绘制组件，确保频点正确性与性能（TDD）。

## 测试优先（TDD）
- ✔ [1] 先编写 gtest：单频信号 FFT 频点正确；窗口/重叠配置生效。
- ✔ [2] Dart Widget/GD 测试：固定谱数据渲染一致。
- ✔ [3] 性能 smoke 用例：频谱刷新不明显掉帧。

## 开发任务
- ✔ [4] 原生：窗口化（Hann/Hamming），集成 FFT（KissFFT），生成功率谱；配置窗口大小/重叠度。
- ✔ [5] 事件推送：频谱数据 + 元数据（窗口、bin 宽度、时间戳）。
- ✔ [6] Dart：`SpectrumView` 绘制组件，支持线性/对数幅度显示基础样式。
- ✖ [7] 与节流策略协同，控制推送频率。

## 完成标准（DoD）
- ✖ [8] gtest/Dart Widget 测试通过；性能 smoke 通过。
