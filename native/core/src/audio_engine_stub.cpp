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
};

std::unique_ptr<AudioEngine> CreateAudioEngineStub() {
  return std::make_unique<AudioEngineStub>();
}

}  // namespace sw
