# SoundWave Native Core (Bootstrap)

跨平台音频核心骨架（当前为桩实现）：
- 接口：`include/audio_engine.h` 暴露 `AudioConfig`、`Status`、`PlaybackState`、`StateEvent`、`PcmFrame`、`AudioEngine` 抽象，以及 `CreateAudioEngineStub()` 工厂。
- 功能：仅空实现，所有操作返回 `Status::kOk`；回调 setter 可注册但不会触发（后续实现）。
- 构建：`cmake -S . -B build -DSW_BUILD_TESTS=ON -DGTest_DIR=/usr/local/lib/cmake/GTest -DCMAKE_OSX_ARCHITECTURES=arm64`
- 测试：`cmake --build build && ctest --test-dir build`
- 平台：开启 `POSITION_INDEPENDENT_CODE`，测试在非 ANDROID/IOS 下启用，gtest 未找到时跳过。

后续工作（规划）：
- 实现解码/缓冲/时钟、回调触发，支持 iOS/Android toolchain。
- 完善状态码/错误枚举和线程安全约束。
