# Story 02：PCM Ingress 接口定义与实现

## 目标
- 定义并实现 SDK 接收上层解码 PCM 的接口（格式/帧长/节流/时间戳），提供波形/频谱订阅的基础事件模型。

## 测试优先（TDD）
- ✔️ [1] PCM 输入校验单测：采样率/通道突变、帧长异常、空数据等返回预期错误码。
- ✔️ [2] 节流与序号单测：推送固定序列，验证节流生效、序号/时间戳连续性。
- ✖️ [3] 接口契约测试：MethodChannel API 映射（push/subscribe/unsubscribe）行为正确。

## 开发任务
- ✔️ [4] 设计 PCM 帧数据结构（samples/sr/ch/ts/seq/frameSize），实现 ingress 校验与缓冲。
- ✖️ [5] 实现波形/频谱订阅事件骨架（暂用占位 FFT 输出），含错误回调。
- ✖️ [6] 插件层映射 push/subscribe/unsubscribe API，补充文档与示例调用。

## 完成标准（DoD）
- ✖️ [7] 单测/契约测试通过；错误码覆盖格式异常/缓冲过载。
- ✖️ [8] 文档更新（API/示例），接口定义与 PRD/计划一致；回归 flutter analyze 通过。 
