# SoundWave Native Core (Bootstrap)

跨平台音频核心骨架（当前为桩实现，聚焦环形缓冲/回放线程/FFT 验证）。适合验证数据结构与时序，不含真实解码与事件回调。

## 适用场景与现状
- 场景：为 Flutter 插件/原生宿主提供统一的 PCM 处理与频谱计算核心。
- 当前状态：解码/回调为桩，环形缓冲与回放线程可用，FFT 计算路径可用；接口稳定性仍在演进。

## 组件概览
- 接口定义：`include/audio_engine.h` 暴露 `AudioConfig`、`Status`、`PlaybackState`、`StateEvent`、`PcmFrame`、`AudioEngine` 抽象，工厂 `CreateAudioEngineStub()`。
- 环形缓冲：`include/ring_buffer.h` / `src/ring_buffer.cpp`，互斥保护的多通道交错 PCM 缓冲，支持水位查询/清空；测试见 `tests/ring_buffer_test.cpp`。
- 回放线程：`include/playback_thread.h` / `src/playback_thread.cpp`，按采样率从环形缓冲拉取数据推进时钟，提供位置回调；测试见 `tests/playback_thread_test.cpp`。
- FFT：KissFFT 路径，downmix 为单声道后窗口化，输出幅度/功率谱；性能烟测脚本见 `scripts/run_perf_smoke.sh`。

## 工作原理（当前桩实现）
- 数据流：上层解码（或桩）→ 写入环形缓冲 → 回放线程按采样率拉取 → 推进播放位置 → （未来）事件回调 → FFT 对拉取的帧做频谱输出。
- 线程模型：写线程（生产 PCM）、读线程（回放/FFT），环形缓冲用互斥保护；回放线程内部用睡眠控制节奏模拟音频时钟。
- 未实现：真实解码器、状态/PCM 回调触发，仅提供接口占位和错误码。

## 快速开始（构建与测试）
前置依赖：CMake >= 3.20、Clang/GCC、gtest（可通过包管理器安装，如 macOS `brew install googletest`；或用 `-DGTest_DIR=...` 指定）。

```bash
# 配置（含测试）
cmake -S . -B build -DSW_BUILD_TESTS=ON -DGTest_DIR=/usr/local/lib/cmake/GTest -DCMAKE_OSX_ARCHITECTURES=arm64
# 编译
cmake --build build
# 运行全部测试
ctest --test-dir build
# 仅跑环形缓冲/回放线程
ctest --test-dir build -R "ring_buffer_tests|playback_thread_tests"
# 性能烟测（FFT 无 NaN/Inf、基础对齐）
native/core/scripts/run_perf_smoke.sh build
```
- 交叉构建：默认仅在非 ANDROID/IOS 平台启用测试；移动端 toolchain 后续补充。
- 常见错误：找不到 gtest → 确认 `GTest_DIR` 或安装路径；架构不符 → 设置 `-DCMAKE_OSX_ARCHITECTURES=` 对应本机。

## 最小使用示例（桩）
```cpp
#include "include/audio_engine.h"
using namespace soundwave;

int main() {
  auto engine = CreateAudioEngineStub();
  AudioConfig config;
  config.sample_rate = 48000;
  config.channels = 2;
  config.buffer_size = 2048;
  if (engine->Init(config) != Status::kOk) return -1;

  PcmFrame frame;
  frame.channels = 2;
  frame.sample_rate = 48000;
  frame.timestamp_ms = 0;
  frame.sequence = 0;
  frame.samples = std::vector<float>(2048, 0.0f); // 交错数据
  engine->WritePcmFrame(frame); // 回放线程将读取并推进时钟

  // ...（后续可调用 Seek/Play/Pause 等，当前为桩，不触发回调）
  engine->Shutdown();
  return 0;
}
```

## API 与状态码
- 生命周期（预期行为）：`Init(config)` → `Load(source)` → `Play/Pause/Stop/Seek` → `Shutdown`。当前桩仅校验参数并维护状态。
- 关键结构：
  - `AudioConfig{sample_rate, channels, buffer_size, network/playback/visualization 可选字段}`。
  - `PcmFrame{sequence, timestamp_ms, sample_rate, channels, samples}`，samples 需为交错数据，长度可被通道数整除。
  - `StateEvent` 预留：播放状态/缓冲/错误（桩不触发）。
- 状态码与触发场景：
  - `kOk` 成功。
  - `kInvalidArguments`：采样率/通道/缓冲大小 <=0，源为空，或帧长度与通道不匹配。
  - `kInvalidState`：未 `Init` 直接调用播放/加载。
  - `kNotSupported`：不支持的格式（桩）。
  - `kIoError`：资源缺失（桩模拟）。
  - `kError`：其他解码/内部错误（桩）。

## FFT 输出说明
- 输入：多声道 PCM 先 downmix 为 `(L+R+..)/channels`；支持窗口化（Hann/Hamming），窗长由调用方设定。
- 输出：KissFFT 幅度/功率谱，已按窗口系数与信号幅度归一；`binHz = sampleRate / windowSize`，DC 分量接近平均幅值。
- 性能/对齐：`scripts/run_perf_smoke.sh` 会运行 `FftSpectrumTest.PerformanceSmokeNoNanOrInf` 等用例，确保无 NaN/Inf 及基本幅值对齐。

## 后续计划
- 落地真实解码/缓冲/时钟与事件回调，完善线程安全约束。
- 完善错误枚举与跨平台构建脚本（iOS/Android toolchain）。
- 增补文档：移动端交叉构建指引、示例回调处理。 
