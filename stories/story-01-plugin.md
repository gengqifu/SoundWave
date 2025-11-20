# Story 01：Flutter 插件骨架

## 目标
创建 Flutter 插件 `soundwave_player` 的基础框架，定义 Method/EventChannel 接口雏形，支持 `init/load/play/pause/stop/seek` 空实现，具备参数校验和错误返回（TDD）。

## 测试优先（TDD）
- 先编写 Dart 单测：MethodChannel 调用契约、参数校验、错误映射；EventChannel 订阅/取消。
- 确保 `flutter analyze`、`flutter test` 作为初始空实现的门禁。

## 开发任务
- 使用 `flutter create --template=plugin soundwave_player` 初始化插件工程。
- 定义平台无关的 Dart API：`init(config)`, `load(source)`, `play()`, `pause()`, `stop()`, `seek(ms)`.
- 建立 EventChannel 事件流（state/pcm/spectrum 占位），返回标准错误码/错误文本。
- 参数校验与错误映射：非法参数、未初始化调用、重复调用等。
- 配置 `flutter analyze`、format 钩子。

## 完成标准（DoD）
- 单测通过：MethodChannel/参数校验/错误映射；EventChannel 订阅/取消。
- `flutter analyze` 通过；`flutter test` 通过。
- README 简要说明调用方式。
