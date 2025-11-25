# SoundWave Native Core (Bootstrap)

跨平台音频核心骨架（当前为桩实现，已包含环形缓冲与回放线程模拟）：
- 接口：`include/audio_engine.h` 暴露 `AudioConfig`、`Status`、`PlaybackState`、`StateEvent`、`PcmFrame`、`AudioEngine` 抽象，以及 `CreateAudioEngineStub()` 工厂。
- 环形缓冲：`include/ring_buffer.h`/`src/ring_buffer.cpp`，互斥保护的多通道交错 PCM 环形缓冲，支持容量水位查询、清空，单元/并发/性能 smoke 测试见 `tests/ring_buffer_test.cpp`。
- 回放线程：`include/playback_thread.h`/`src/playback_thread.cpp`，从环形缓冲拉取数据按采样率推进时钟，提供位置回调，测试见 `tests/playback_thread_test.cpp`。
- 功能（桩行为）：解码器支持 mp3/aac/m4a/wav/flac，文件缺失/不支持/解码失败会返回对应错误码；回调 setter 可注册但不会触发（后续实现）。
- 状态码：`kOk` 成功；`kInvalidArguments` 参数错误（空源、采样率/通道非法）；`kInvalidState` 未初始化直接加载；`kNotSupported` 不支持的格式；`kIoError` 资源缺失；`kError` 其他解码错误。
- 构建：`cmake -S . -B build -DSW_BUILD_TESTS=ON -DGTest_DIR=/usr/local/lib/cmake/GTest -DCMAKE_OSX_ARCHITECTURES=arm64`
- 测试：`cmake --build build && ctest --test-dir build` 或单独运行 `ctest -R ring_buffer_tests|playback_thread_tests`。
- 平台：开启 `POSITION_INDEPENDENT_CODE`，测试在非 ANDROID/IOS 下启用，gtest 未找到时跳过。

后续工作（规划）：
- 实现解码/缓冲/时钟、回调触发，支持 iOS/Android toolchain。
- 完善状态码/错误枚举和线程安全约束。

## FFmpeg 编译指引（源码位于 `ffmpeg/`）

- iOS（arm64）：`native/core/scripts/build_ffmpeg_ios.sh`，输出到 `ffmpeg/build/ios/arm64`（可调整 `PREFIX`）。
- Android（arm64-v8a 默认）：设置 `NDK=/path/to/ndk`，运行 `native/core/scripts/build_ffmpeg_android.sh`，输出到 `ffmpeg/build/android/arm64-v8a`（可通过 `ABI` 选择其他架构）。
- 可调整的配置项：
  - `FFSRC`：FFmpeg 源码路径（默认 `../ffmpeg`）。
  - `PREFIX`：安装输出路径。
  - `API`（Android）：API 级别，默认 24。
  - `ABI`（Android）：`arm64-v8a` / `armeabi-v7a` / `x86_64`。
- 配置特性（默认启用）：解码器 `aac, mp3, flac, pcm_s16le, pcm_f32le`；demuxer `mov, mp3, aac, flac, wav`；protocol `file, http, https`；静态库 + PIC，关闭程序/文档/调试。
- 运行前如修改了 configure 参数，建议 `make distclean` 清理旧配置。

## CMake 集成 FFmpeg

- 默认 `SW_ENABLE_FFMPEG=ON`，优先使用 FFmpeg 解码；若 FFmpeg 无法打开，则自动回退到桩实现。
- 路径配置示例（需包含 `include/` 与 `lib/`）：
  - 桌面：`-DFFMPEG_ROOT_DESKTOP=/Users/gengqifu/git/ext/SoundWave/ffmpeg/build/desktop`（默认值）
  - iOS：`-DFFMPEG_ROOT_IOS=/Users/gengqifu/git/ext/SoundWave/ffmpeg/build/ios/arm64`
  - Android：`-DFFMPEG_ROOT_ANDROID=/Users/gengqifu/git/ext/SoundWave/ffmpeg/build/android/arm64-v8a`
- 链接库：`avformat avcodec avutil swresample swscale`；macOS 需额外链接 Security/CoreFoundation/CoreVideo/VideoToolbox/AudioToolbox/CoreMedia/AVFoundation/iconv/z/bz2。
