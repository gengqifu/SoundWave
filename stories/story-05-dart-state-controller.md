# Story 05：Dart 层状态与控制器

## 目标
实现 Dart 层 `AudioState` 与控制器，封装 `init/load/play/pause/seek` 调用，处理 `onState` 事件与错误提示，保障状态流正确（TDD）。

## 测试优先（TDD）
- ✔ [1] 先编写 Dart 单测：状态流变更、错误分支、未初始化调用防护。
- ✖ [2] Widget/GD 测试：基础控件状态展示正确（可用占位 UI）。

## 开发任务
- ✖ [3] 定义 `AudioState` 数据结构（position/duration/isPlaying/buffered/levels/spectrum）。
- ✖ [4] 编写 Controller（Riverpod/BLoC/Provider 选型）封装插件调用，处理事件流。
- ✖ [5] 错误映射与用户可读提示。
- ✖ [6] 基础 UI 状态绑定（不含绘制组件）。

## 完成标准（DoD）
- ✖ [7] `flutter analyze/test` 通过；单测/Widget 测试覆盖主要状态流与错误分支。
