#include "audio_engine.h"

namespace sw {

class AudioEngineStub : public AudioEngine {
 public:
  Status Init(const AudioConfig& /*config*/) override { return Status::kOk; }
  Status Load(const std::string& /*source*/) override { return Status::kOk; }
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
