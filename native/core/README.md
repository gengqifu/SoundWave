# SoundWave Native Core (Bootstrap)

跨平台音频核心骨架（当前为桩实现）：
- 接口：`include/audio_engine.h` 暴露 `AudioConfig`、`Status`、`PlaybackState`、`StateEvent`、`PcmFrame`、`AudioEngine` 抽象，以及 `CreateAudioEngineStub()` 工厂。
- 功能（桩行为）：解码器支持 mp3/aac/m4a/wav/flac，文件缺失/不支持/解码失败会返回对应错误码；回调 setter 可注册但不会触发（后续实现）。
- 状态码：`kOk` 成功；`kInvalidArguments` 参数错误（空源、采样率/通道非法）；`kInvalidState` 未初始化直接加载；`kNotSupported` 不支持的格式；`kIoError` 资源缺失；`kError` 其他解码错误。
- 构建：`cmake -S . -B build -DSW_BUILD_TESTS=ON -DGTest_DIR=/usr/local/lib/cmake/GTest -DCMAKE_OSX_ARCHITECTURES=arm64`
- 测试：`cmake --build build && ctest --test-dir build`
- 平台：开启 `POSITION_INDEPENDENT_CODE`，测试在非 ANDROID/IOS 下启用，gtest 未找到时跳过。

后续工作（规划）：
- 实现解码/缓冲/时钟、回调触发，支持 iOS/Android toolchain。
- 完善状态码/错误枚举和线程安全约束。
