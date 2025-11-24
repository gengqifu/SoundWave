#include "audio_engine.h"
#include "decoder.h"

#include <memory>
#include <string>

namespace sw {

class AudioEngineStub : public AudioEngine {
 public:
  AudioEngineStub() { EnsureDecoder(); }

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
  Status Play() override { return Status::kOk; }
  Status Pause() override { return Status::kOk; }
  Status Stop() override { return Status::kOk; }
  Status Seek(int64_t /*position_ms*/) override { return Status::kOk; }

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
  std::unique_ptr<Decoder> decoder_;

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
};

std::unique_ptr<AudioEngine> CreateAudioEngineStub() {
  return std::make_unique<AudioEngineStub>();
}

}  // namespace sw
