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

}  // namespace sw
