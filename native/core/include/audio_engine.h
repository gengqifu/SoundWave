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
};

// Factory for the stub implementation used in bootstrap/testing.
std::unique_ptr<AudioEngine> CreateAudioEngineStub();

}  // namespace sw
