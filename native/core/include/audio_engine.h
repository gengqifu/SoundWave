#pragma once

#include <cstdint>
#include <memory>
#include <string>

#include "fft_spectrum.h"

namespace sw {

struct AudioConfig {
  int sample_rate = 48000;
  int channels = 2;
  int frames_per_buffer = 0;  // optional override.
  // PCM 可视化相关配置。
  int pcm_max_fps = 60;          // 推送频率上限（帧/秒）。
  int pcm_frames_per_push = 0;   // 每次推送的帧数，0 则使用 frames_per_buffer。
  size_t pcm_max_pending = 4;    // 限频时最多排队的帧数，超出立即丢弃并标记。
  int spectrum_max_fps = 30;     // 频谱推送频率上限（帧/秒，默认低于 PCM）。
  size_t spectrum_max_pending = 2;  // 频谱待发上限。
  SpectrumConfig spectrum_cfg;    // 频谱计算配置。
};

enum class Status {
  kOk = 0,
  kError = 1,
  kInvalidState = 2,
  kInvalidArguments = 3,
  kNotSupported = 4,
  kIoError = 5,
};

enum class PlaybackState {
  kIdle = 0,
  kInitialized,
  kReady,
  kPlaying,
  kPaused,
  kStopped,
};

struct StateEvent {
  PlaybackState state;
  Status status;
};

struct PcmFrame {
  const float* data = nullptr;
  int num_frames = 0;
  int num_channels = 0;
  int sample_rate = 0;
  int64_t timestamp_ms = 0;  // presentation time.
};

struct SpectrumFrame {
  const float* bins = nullptr;
  int num_bins = 0;           // window_size/2 + 1
  int window_size = 0;
  float bin_hz = 0.0f;
  int sample_rate = 0;
  WindowType window = WindowType::kHann;
  bool power_spectrum = true;  // true: power, false: magnitude.
  int64_t timestamp_ms = 0;
};

// Minimal audio engine interface (stub for TDD).
class AudioEngine {
 public:
  virtual ~AudioEngine() = default;

  virtual Status Init(const AudioConfig& config) = 0;
  virtual Status Load(const std::string& source) = 0;
  virtual Status Play() = 0;
  virtual Status Pause() = 0;
  virtual Status Stop() = 0;
  virtual Status Seek(int64_t position_ms) = 0;

  // Event callbacks (will be invoked from internal threads; caller ensures thread-safety).
  virtual void SetStateCallback(void (*callback)(const StateEvent&, void*), void* user_data) = 0;
  virtual void SetPcmCallback(void (*callback)(const PcmFrame&, void*), void* user_data) = 0;
  virtual void SetPositionCallback(void (*callback)(int64_t position_ms, void*), void* user_data) = 0;
  virtual void SetSpectrumCallback(void (*callback)(const SpectrumFrame&, void*),
                                   void* user_data) = 0;
};

// Factory for the stub implementation used in bootstrap/testing.
std::unique_ptr<AudioEngine> CreateAudioEngineStub();

}  // namespace sw
#include "fft_spectrum.h"
