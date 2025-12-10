# SoundWave Native Core (Bootstrap)

跨平台音频核心骨架（当前为桩实现，已包含环形缓冲与回放线程模拟）：
- 接口：`include/audio_engine.h` 暴露 `AudioConfig`、`Status`、`PlaybackState`、`StateEvent`、`PcmFrame`、`AudioEngine` 抽象，以及 `CreateAudioEngineStub()` 工厂。
- 环形缓冲：`include/ring_buffer.h`/`src/ring_buffer.cpp`，互斥保护的多通道交错 PCM 环形缓冲，支持容量水位查询、清空，单元/并发/性能 smoke 测试见 `tests/ring_buffer_test.cpp`。
- 回放线程：`include/playback_thread.h`/`src/playback_thread.cpp`，从环形缓冲拉取数据按采样率推进时钟，提供位置回调，测试见 `tests/playback_thread_test.cpp`。
- 功能（桩行为）：解码器支持 mp3/aac/m4a/wav/flac（桩），文件缺失/不支持/解码失败会返回对应错误码；回调 setter 可注册但不会触发（后续实现）。
- 状态码：`kOk` 成功；`kInvalidArguments` 参数错误（空源、采样率/通道非法）；`kInvalidState` 未初始化直接加载；`kNotSupported` 不支持的格式；`kIoError` 资源缺失；`kError` 其他解码错误。
- 构建：`cmake -S . -B build -DSW_BUILD_TESTS=ON -DGTest_DIR=/usr/local/lib/cmake/GTest -DCMAKE_OSX_ARCHITECTURES=arm64`
- 测试：`cmake --build build && ctest --test-dir build` 或单独运行 `ctest -R ring_buffer_tests|playback_thread_tests`。
- 平台：开启 `POSITION_INDEPENDENT_CODE`，测试在非 ANDROID/IOS 下启用，gtest 未找到时跳过。
- FFT 参数：PCM 多声道输入会 downmix 为 `(L+R+..)/channels` 后做窗口化；KissFFT 输出按窗口系数和信号幅度归一化，DC 分量约等于输入平均幅值，`binHz = sampleRate / windowSize`。
- 性能烟测：`native/core/scripts/run_perf_smoke.sh [build_dir]` 自动配置/构建并运行 `FftSpectrumTest.PerformanceSmokeNoNanOrInf` 与跨端对齐用例，必要时传入 `CMAKE_FLAGS="-DGTest_DIR=..."`。

后续工作（规划）：
- 实现解码/缓冲/时钟、回调触发，支持 iOS/Android toolchain（现阶段由上层播放器提供解码，核心聚焦 PCM 处理）。
- 完善状态码/错误枚举和线程安全约束。
