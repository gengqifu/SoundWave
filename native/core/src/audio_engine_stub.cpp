#include "audio_engine.h"
#include "decoder.h"
#include "playback_thread.h"
#include "ring_buffer.h"

#include <atomic>
#include <chrono>
#include <memory>
#include <string>
#include <thread>
#include <vector>

namespace sw {

class AudioEngineStub : public AudioEngine {
 public:
  AudioEngineStub() { EnsureDecoder(); }

  ~AudioEngineStub() override { ShutdownPlayback(); }

  Status Init(const AudioConfig& config) override {
    if (config.sample_rate <= 0 || config.channels <= 0) {
      return Status::kInvalidArguments;
    }
    EnsureDecoder();
    last_sample_rate_ = config.sample_rate;
    last_channels_ = config.channels;
    if (!decoder_->ConfigureOutput(config.sample_rate, config.channels)) {
      return decoder_->last_status();
    }
    cfg_ = config;
    if (cfg_.frames_per_buffer <= 0) {
      cfg_.frames_per_buffer = kDefaultFramesPerBuffer;
    }
    ring_buffer_ = std::make_unique<RingBuffer>(kRingBufferCapacityFrames, cfg_.channels);
    playback_thread_ =
        std::make_unique<PlaybackThread>(*ring_buffer_, PlaybackConfig{cfg_.sample_rate,
                                                                       cfg_.channels,
                                                                       cfg_.frames_per_buffer});
    playback_thread_->SetPositionCallback([this](int64_t pos_ms) {
      if (pos_cb_) {
        pos_cb_(pos_ms, pos_ud_);
      }
    });

    initialized_ = true;
    loaded_ = false;
    return Status::kOk;
  }
  Status Load(const std::string& source) override {
    if (!initialized_) {
      return Status::kInvalidState;
    }
    if (source.empty()) {
      return Status::kInvalidArguments;
    }
    EnsureDecoder();
    if (!decoder_->Open(source)) {
#ifdef SW_ENABLE_FFMPEG
      // Fallback to stub if FFmpeg decoder fails to open (e.g., missing file or unsupported).
      decoder_ = CreateStubDecoder();
      if (decoder_) {
        decoder_->ConfigureOutput(last_sample_rate_, last_channels_);
      }
#endif
    }
    if (decoder_ && !decoder_->Open(source)) {
      return decoder_->last_status();
    }
    loaded_ = true;
    return Status::kOk;
  }
  Status Play() override {
    if (!initialized_ || !loaded_) {
      return Status::kInvalidState;
    }
    if (playing_) {
      return Status::kOk;
    }
    StartFeeder();
    if (playback_thread_ && !playback_thread_->running()) {
      playback_thread_->Start();
    }
    playing_ = true;
    EmitState(PlaybackState::kPlaying, Status::kOk);
    return Status::kOk;
  }
  Status Pause() override {
    if (!initialized_) {
      return Status::kInvalidState;
    }
    StopPlayback();
    EmitState(PlaybackState::kPaused, Status::kOk);
    return Status::kOk;
  }
  Status Stop() override {
    if (!initialized_) {
      return Status::kInvalidState;
    }
    StopPlayback();
    if (ring_buffer_) {
      ring_buffer_->Clear();
    }
    if (playback_thread_) {
      playback_thread_->ResetPosition(0);
    }
    EmitState(PlaybackState::kStopped, Status::kOk);
    return Status::kOk;
  }
  Status Seek(int64_t position_ms) override {
    if (!initialized_ || !loaded_) {
      return Status::kInvalidState;
    }
    if (position_ms < 0) {
      return Status::kInvalidArguments;
    }
    if (playback_thread_) {
      playback_thread_->ResetPosition(position_ms);
    }
    return Status::kOk;
  }

  void SetStateCallback(void (*callback)(const StateEvent&, void*), void* user_data) override {
    state_cb_ = callback;
    state_ud_ = user_data;
  }

  void SetPcmCallback(void (*callback)(const PcmFrame&, void*), void* user_data) override {
    pcm_cb_ = callback;
    pcm_ud_ = user_data;
  }

  void SetPositionCallback(void (*callback)(int64_t, void*), void* user_data) override {
    pos_cb_ = callback;
    pos_ud_ = user_data;
  }

 private:
  bool initialized_ = false;
  bool loaded_ = false;
  int last_sample_rate_ = 48000;
  int last_channels_ = 2;
  AudioConfig cfg_;
  std::unique_ptr<Decoder> decoder_;
  std::unique_ptr<RingBuffer> ring_buffer_;
  std::unique_ptr<PlaybackThread> playback_thread_;
  std::thread feeder_thread_;
  std::atomic<bool> feeder_running_{false};
  std::atomic<bool> playing_{false};

  void EnsureDecoder() {
#ifdef SW_ENABLE_FFMPEG
    if (!decoder_) {
      decoder_ = CreateFFmpegDecoder();
    }
#endif
    if (!decoder_) {
      decoder_ = CreateStubDecoder();
    }
  }

  void (*state_cb_)(const StateEvent&, void*) = nullptr;
  void* state_ud_ = nullptr;

  void (*pcm_cb_)(const PcmFrame&, void*) = nullptr;
  void* pcm_ud_ = nullptr;

  void (*pos_cb_)(int64_t, void*) = nullptr;
  void* pos_ud_ = nullptr;

  static constexpr int kDefaultFramesPerBuffer = 256;
  static constexpr int kRingBufferCapacityFrames = 4096;

  void EmitState(PlaybackState state, Status status) {
    if (state_cb_) {
      StateEvent ev{state, status};
      state_cb_(ev, state_ud_);
    }
  }

  void StartFeeder() {
    if (feeder_running_.exchange(true)) {
      return;
    }
    feeder_thread_ = std::thread([this]() {
      const size_t frames = static_cast<size_t>(cfg_.frames_per_buffer);
      std::vector<float> silence(frames * static_cast<size_t>(cfg_.channels), 0.0f);
      while (feeder_running_.load()) {
        if (!ring_buffer_) {
          std::this_thread::sleep_for(std::chrono::milliseconds(1));
          continue;
        }
        size_t wrote = ring_buffer_->Write(silence.data(), frames);
        if (wrote == 0) {
          std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
      }
    });
  }

  void StopFeeder() {
    feeder_running_.store(false);
    if (feeder_thread_.joinable()) {
      feeder_thread_.join();
    }
  }

  void StopPlayback() {
    if (!playing_) {
      StopFeeder();
      if (playback_thread_) {
        playback_thread_->Stop();
      }
      return;
    }
    playing_ = false;
    StopFeeder();
    if (playback_thread_) {
      playback_thread_->Stop();
    }
  }

  void ShutdownPlayback() {
    StopPlayback();
  }
};

std::unique_ptr<AudioEngine> CreateAudioEngineStub() {
  return std::make_unique<AudioEngineStub>();
}

}  // namespace sw
