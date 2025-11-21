#pragma once

#include <cstdint>
#include <memory>
#include <string>

namespace sw {

struct AudioConfig {
  int sample_rate = 48000;
  int channels = 2;
  int frames_per_buffer = 0;  // optional override.
};

enum class Status {
  kOk = 0,
  kError = 1,
  kInvalidState = 2,
  kInvalidArguments = 3,
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
};

// Factory for the stub implementation used in bootstrap/testing.
std::unique_ptr<AudioEngine> CreateAudioEngineStub();

}  // namespace sw
