#include "audio_engine.h"

#include <gtest/gtest.h>
#include <memory>

namespace sw {

class AudioEngineTest : public ::testing::Test {
 protected:
  void SetUp() override { engine_ = CreateAudioEngineStub(); }
  std::unique_ptr<AudioEngine> engine_;
};

TEST_F(AudioEngineTest, LifecycleDoesNotCrash) {
  ASSERT_NE(engine_, nullptr);
  AudioConfig cfg;
  EXPECT_EQ(engine_->Init(cfg), Status::kOk);
  EXPECT_EQ(engine_->Load("file://sample"), Status::kOk);
  EXPECT_EQ(engine_->Play(), Status::kOk);
  EXPECT_EQ(engine_->Pause(), Status::kOk);
  EXPECT_EQ(engine_->Seek(1000), Status::kOk);
  EXPECT_EQ(engine_->Stop(), Status::kOk);
}

TEST_F(AudioEngineTest, CallbacksCanBeSet) {
  ASSERT_NE(engine_, nullptr);
  bool state_called = false;
  bool pcm_called = false;
  bool pos_called = false;

  engine_->SetStateCallback(
      [](const StateEvent&, void* ud) { *static_cast<bool*>(ud) = true; }, &state_called);
  engine_->SetPcmCallback(
      [](const PcmFrame&, void* ud) { *static_cast<bool*>(ud) = true; }, &pcm_called);
  engine_->SetPositionCallback(
      [](int64_t, void* ud) { *static_cast<bool*>(ud) = true; }, &pos_called);

  // Callbacks are not invoked in stub, but setting them should not crash.
  EXPECT_FALSE(state_called);
  EXPECT_FALSE(pcm_called);
  EXPECT_FALSE(pos_called);
}

}  // namespace sw
