#include "audio_engine.h"
#include "decoder.h"
#include "fft_spectrum.h"
#include "pcm_throttler.h"
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
    if (cfg_.spectrum_cfg.window_size <= 0) {
      cfg_.spectrum_cfg.window_size = cfg_.frames_per_buffer;
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
    PcmThrottleConfig throttle_cfg;
    throttle_cfg.max_fps = cfg_.pcm_max_fps;
    throttle_cfg.max_pending = cfg_.pcm_max_pending;
    throttler_ = std::make_unique<PcmThrottler>(throttle_cfg);
    PcmThrottleConfig spectrum_cfg;
    spectrum_cfg.max_fps = cfg_.spectrum_max_fps > 0 ? cfg_.spectrum_max_fps : cfg_.pcm_max_fps;
    spectrum_cfg.max_pending =
        cfg_.spectrum_max_pending > 0 ? cfg_.spectrum_max_pending : cfg_.pcm_max_pending;
    spectrum_throttler_ = std::make_unique<PcmThrottler>(spectrum_cfg);
    pcm_sequence_.store(0);
    pcm_timestamp_ms_.store(0);
    spectrum_sequence_.store(0);

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

  void SetSpectrumCallback(void (*callback)(const SpectrumFrame&, void*),
                           void* user_data) override {
    spectrum_cb_ = callback;
    spectrum_ud_ = user_data;
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
  std::unique_ptr<PcmThrottler> throttler_;
  std::unique_ptr<PcmThrottler> spectrum_throttler_;
  std::atomic<uint32_t> pcm_sequence_{0};
  std::atomic<int64_t> pcm_timestamp_ms_{0};
  std::atomic<uint32_t> spectrum_sequence_{0};

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

  void (*spectrum_cb_)(const SpectrumFrame&, void*) = nullptr;
  void* spectrum_ud_ = nullptr;

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
      const size_t frames = static_cast<size_t>(
          cfg_.pcm_frames_per_push > 0 ? cfg_.pcm_frames_per_push : cfg_.frames_per_buffer);
      std::vector<float> silence(frames * static_cast<size_t>(cfg_.channels), 0.0f);
      const int64_t frame_duration_ms =
          static_cast<int64_t>((frames * 1000) / static_cast<size_t>(cfg_.sample_rate));
      while (feeder_running_.load()) {
        if (!ring_buffer_) {
          std::this_thread::sleep_for(std::chrono::milliseconds(1));
          continue;
        }
        size_t wrote = ring_buffer_->Write(silence.data(), frames);
        if (wrote == 0) {
          std::this_thread::sleep_for(std::chrono::milliseconds(1));
          continue;
        }
        // 可视化 PCM 推送（交错 float32）。
        if (pcm_cb_ && throttler_) {
          PcmThrottleInput in;
          in.sequence = pcm_sequence_.fetch_add(1) + 1;
          in.timestamp_ms = pcm_timestamp_ms_.load();
          in.num_frames = static_cast<int>(frames);
          in.num_channels = cfg_.channels;
          auto outs = throttler_->Push(in, in.timestamp_ms);
          for (const auto& o : outs) {
            if (o.dropped) {
              MaybeEmitSpectrum(/*frame=*/std::nullopt, o.timestamp_ms);
              continue;
            }
            PcmFrame frame;
            frame.data = silence.data();
            frame.num_frames = in.num_frames;
            frame.num_channels = in.num_channels;
            frame.sample_rate = cfg_.sample_rate;
            frame.timestamp_ms = o.timestamp_ms;
            pcm_cb_(frame, pcm_ud_);
            MaybeEmitSpectrum(frame, o.timestamp_ms);
          }
        }
        pcm_timestamp_ms_.fetch_add(frame_duration_ms);
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

  void MaybeEmitSpectrum(std::optional<PcmFrame> frame_opt, int64_t timestamp_ms) {
    if (!spectrum_cb_ || !spectrum_throttler_) return;
    const uint32_t seq = spectrum_sequence_.fetch_add(1) + 1;
    PcmThrottleInput in;
    in.sequence = seq;
    in.timestamp_ms = timestamp_ms;
    in.num_frames = frame_opt ? frame_opt->num_frames : 0;
    in.num_channels = frame_opt ? frame_opt->num_channels : 0;

    const auto outs = spectrum_throttler_->Push(in, timestamp_ms);
    for (const auto& o : outs) {
      if (o.dropped || !frame_opt) {
        continue;
      }
      const PcmFrame& frame = *frame_opt;
      const int samples_per_channel = frame.num_frames;
      if (frame.num_channels <= 0 || samples_per_channel <= 0) continue;

      SpectrumConfig spec_cfg = cfg_.spectrum_cfg;
      if (spec_cfg.window_size <= 0 || spec_cfg.window_size > samples_per_channel) {
        spec_cfg.window_size = samples_per_channel;
      }

      std::vector<float> mono(static_cast<size_t>(spec_cfg.window_size));
      for (int i = 0; i < spec_cfg.window_size; ++i) {
        mono[static_cast<size_t>(i)] = frame.data[i * frame.num_channels];
      }

      auto spectrum = ComputeSpectrum(mono, frame.sample_rate, spec_cfg);
      if (spectrum.empty()) continue;

      SpectrumFrame out;
      out.bins = spectrum.data();
      out.num_bins = static_cast<int>(spectrum.size());
      out.window_size = spec_cfg.window_size;
      out.bin_hz = static_cast<float>(frame.sample_rate) /
                   static_cast<float>(spec_cfg.window_size);
      out.sample_rate = frame.sample_rate;
      out.window = spec_cfg.window;
      out.power_spectrum = spec_cfg.power_spectrum;
      out.timestamp_ms = o.timestamp_ms;
      spectrum_cb_(out, spectrum_ud_);
    }
  }
};

std::unique_ptr<AudioEngine> CreateAudioEngineStub() {
  return std::make_unique<AudioEngineStub>();
}

}  // namespace sw
