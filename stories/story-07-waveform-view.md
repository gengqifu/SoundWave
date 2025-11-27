# Story 07：WaveformView 绘制

## 目标
在 Flutter 侧实现时域波形绘制组件 `WaveformView`，支持抽稀/缓存，随 PCM 更新渲染，保持性能（TDD）。

## 测试优先（TDD）
- ✔ [1] 先编写 Widget/GD 测试：给定固定 PCM 数据，输出与基线截图一致。
- ✔ [2] 设计性能 smoke 用例（profile 模式）监控帧率。

## 开发任务
- ✔ [3] 设计数据结构：波形缓存（建议固定时间窗口/最大点数）、抽稀策略（如按像素宽度做 min/max bucket）。
- ✔ [4] 自定义绘制：CustomPainter/Canvas 绘制波形；支持缩放/平移占位（交互后续故事完善），定义基线截图尺寸/DPI。
- ✔ [5] 与 PCM 缓存对接，刷新节流（如每 16ms/60fps），确保渲染负载可控。
- ✔ [6] 简单样式配置（颜色、背景、线宽），明确默认主题。

## 完成标准（DoD）
- ✖ [7] Widget/GD 测试通过，性能 smoke 无明显掉帧。
- ✖ [8] `flutter analyze/test` 通过。
