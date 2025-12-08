# Story 04：可视化后门与测试工具集成

## 目标
- 提供可选的移动端可视化扩展（波形/频谱），受测 App 可通过隐藏开关在播放中调出，辅助实时校验音频链路。

## 测试优先（TDD）
- ✅ [1] 可视化开启/关闭行为：隐藏开关触发后 UI 可正常订阅/取消订阅 PCM/谱事件，不影响播放。（AppBar 长按开启/关闭后门，内部调用 `setVisualizationEnabled` 静音/恢复缓冲）
- ✅ [2] 门禁：相关 Widget/集成测试通过，`flutter analyze`、`flutter test` 通过（包含开关行为单测）。

## 开发任务
- ✅ [3] 定义后门开关接口与安全策略（仅测试环境可用），实现 UI 挂载/卸载。（`SoundwaveConfig.enableVisualizationBackdoor` 需显式开启，`setVisualizationEnabled` 未授权直接抛错；示例通过 AppBar 长按切换）
- ✅ [4] 确保与导出模块兼容，不引入额外性能回退。（后门复用已有 PCM/谱缓冲，无额外平台订阅；关闭时静音丢弃，避免阻塞导出写盘队列；全量 `flutter test` 冒烟）
- ✅ [5] 文档/示例更新：说明开启方式与限制。（README 增加“可视化后门”启用与警示，示例长按 AppBar 触发；默认关闭，仅测试环境设置 `enableVisualizationBackdoor: true`）

## 完成标准（DoD）
- ✅ [6] 可视化后门验证通过，开启/关闭不影响播放与事件序列。（单测覆盖静音/恢复缓冲，冒烟 `flutter test` 通过）
- ✖️ [7] 相关测试与构建门禁通过。
- ✖️ [8] 文档更新，示例可演示后门开关。***
