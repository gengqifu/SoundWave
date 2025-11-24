# Story 03：解码链路 MVP

## 目标
集成 FFmpeg/平台解码器，完成本地文件解码到统一 PCM（float32/16bit 可配置），返回采样率/通道元数据，并处理常见错误（TDD）。

## 测试优先（TDD）
- ✅ [1] 先编写 gtest：已知样本解码成功、采样率/通道数正确；错误路径/不支持格式返回预期错误码。
- ✅ [2] 覆盖配置入口（采样率/通道转换）的参数验证。

## 开发任务
- ✅ [3] 封装解码器接口，支持 mp3/aac/m4a/wav/flac。
- ✅ [4] 解码输出统一 PCM，支持采样率/通道转换配置入口（可暂留 Resampler 占位）。
- ✅ [5] 错误分类与返回（文件不存在、不支持、解码失败）。
- ✅ [6] 与 `AudioEngine` 接口对接，填充 load/init 流程。
- ✅ [7] 引入 FFmpeg 预编译库（iOS/Android），CMake 集成头文件与链接配置，支持本地构建。
- ✅ [8] 实现 `DecoderFFmpeg`（open/read/close/config），按 FFmpeg 错误码映射到统一 `Status`。
- ✖ [9] gtest 覆盖真实解码：小样本文件（mp3/aac/wav/flac）解码成功/错误路径。
- ✖ [10] `AudioEngine` 默认切换到 FFmpeg decoder，保留 stub/平台解码器作为兜底。
- ✖ [11] 文档与脚本：README 增加 FFmpeg 依赖获取方式、构建脚本/缓存策略。

## 完成标准（DoD）
- ✅ [D1] gtest 通过：成功/错误用例覆盖到位。
- ✅ [D2] 性能样本：小文件解码无泄漏/崩溃。
- ✅ [D3] 文档：支持格式列表、错误码说明。
- ✖ [D4] FFmpeg 集成：本地构建可链接 FFmpeg，真实样本解码用例通过。
