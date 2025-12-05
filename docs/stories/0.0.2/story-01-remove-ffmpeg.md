# Story 01：移除 FFmpeg，切换平台解码

## 目标
- 移除 FFmpeg 依赖与二进制，改用 ExoPlayer/MediaCodec 与 AVFoundation 输出 44.1kHz/float32/stereo，保持 PCM/FFT 链路可用。

## 测试优先（TDD）
- ✖️ [1] 本地/HTTP 播放回归：解码输出格式符合 44.1kHz/float32/stereo，PCM 事件节流正常。
- ✖️ [2] 门禁：`flutter analyze`、`flutter test`、Android/iOS 基础构建通过。

## 开发任务
- ✖️ [3] 清理 FFmpeg 预编库、CMake/Gradle/Podspec 引用，移除 native 解码路径。
- ✖️ [4] 平台解码输出对齐：配置采样率/位深/通道，必要时重采样与 downmix。
- ✖️ [5] 更新文档与配置（README/CHANGELOG），声明不再依赖 FFmpeg。

## 完成标准（DoD）
- ✖️ [6] 本地/HTTP 播放用例通过，PCM 事件格式与节流保持一致。
- ✖️ [7] `flutter analyze`、`flutter test` 通过；Android/iOS 构建通过。
- ✖️ [8] 文档更新到位，FFmpeg 相关文件与引用清零。***
