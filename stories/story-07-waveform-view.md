# Story 07：WaveformView 绘制

## 目标
在 Flutter 侧实现时域波形绘制组件 `WaveformView`，支持抽稀/缓存，随 PCM 更新渲染，保持性能（TDD）。

## 测试优先（TDD）
- 先编写 Widget/GD 测试：给定固定 PCM 数据，输出与基线截图一致。
- 设计性能 smoke 用例（profile 模式）监控帧率。

## 开发任务
- 设计数据结构：波形缓存、抽稀策略（如 min/max bucket）。
- 自定义绘制：CustomPainter/Canvas 绘制波形；支持缩放/平移占位（交互后续故事完善）。
- 与 PCM 缓存对接，刷新节流。
- 简单样式配置（颜色、背景、线宽）。

## 完成标准（DoD）
- Widget/GD 测试通过，性能 smoke 无明显掉帧。
- `flutter analyze/test` 通过。
