#include "audio_engine.h"
#include "decoder.h"

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
  EXPECT_EQ(engine_->Load("file:///tmp/sample.mp3"), Status::kOk);
  EXPECT_EQ(engine_->Play(), Status::kOk);
  EXPECT_EQ(engine_->Pause(), Status::kOk);
  EXPECT_EQ(engine_->Seek(1000), Status::kOk);
  EXPECT_EQ(engine_->Stop(), Status::kOk);
}

TEST_F(AudioEngineTest, LoadInvalidSourceReturnsError) {
  ASSERT_NE(engine_, nullptr);
  AudioConfig cfg;
  EXPECT_EQ(engine_->Init(cfg), Status::kOk);
  EXPECT_EQ(engine_->Load(""), Status::kInvalidArguments);
  EXPECT_EQ(engine_->Load("file:///tmp/sample.txt"), Status::kNotSupported);
  EXPECT_EQ(engine_->Load("file:///tmp/missing.mp3"), Status::kIoError);
  EXPECT_EQ(engine_->Load("file:///tmp/decodefail.mp3"), Status::kError);
}

TEST_F(AudioEngineTest, LoadWithoutInitIsInvalidState) {
  ASSERT_NE(engine_, nullptr);
  EXPECT_EQ(engine_->Load("file:///tmp/sample.mp3"), Status::kInvalidState);
}

TEST_F(AudioEngineTest, InitRejectsInvalidConfig) {
  ASSERT_NE(engine_, nullptr);
  AudioConfig bad;
  bad.sample_rate = 0;
  bad.channels = 0;
  EXPECT_EQ(engine_->Init(bad), Status::kInvalidArguments);
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

TEST(DecoderStubTest, OpenAndRead) {
  std::unique_ptr<Decoder> dec = CreateStubDecoder();
  ASSERT_TRUE(dec->Open("file:///tmp/sample.mp3"));
  PcmBuffer buf;
  EXPECT_FALSE(dec->Read(buf));  // EOF
  EXPECT_EQ(buf.sample_rate, 48000);
  EXPECT_EQ(buf.channels, 2);
  EXPECT_EQ(dec->last_status(), Status::kOk);
}

TEST(DecoderStubTest, InvalidSourceReturnsFalse) {
  std::unique_ptr<Decoder> dec = CreateStubDecoder();
  EXPECT_FALSE(dec->Open(""));
  EXPECT_EQ(dec->last_status(), Status::kInvalidArguments);
}

TEST(DecoderStubTest, UnsupportedFormatReturnsFalse) {
  std::unique_ptr<Decoder> dec = CreateStubDecoder();
  EXPECT_FALSE(dec->Open("file:///tmp/sample.txt"));
  EXPECT_EQ(dec->last_status(), Status::kNotSupported);
}

TEST(DecoderStubTest, MissingFileReturnsIoError) {
  std::unique_ptr<Decoder> dec = CreateStubDecoder();
  EXPECT_FALSE(dec->Open("file:///tmp/missing.mp3"));
  EXPECT_EQ(dec->last_status(), Status::kIoError);
}

TEST(DecoderStubTest, DecodeFailureSetsError) {
  std::unique_ptr<Decoder> dec = CreateStubDecoder();
  EXPECT_FALSE(dec->Open("file:///tmp/decodefail.mp3"));
  EXPECT_EQ(dec->last_status(), Status::kError);
}

TEST(DecoderStubTest, ConfigureOutputChangesReportedFormat) {
  std::unique_ptr<Decoder> dec = CreateStubDecoder();
  ASSERT_TRUE(dec->ConfigureOutput(44100, 1));
  ASSERT_TRUE(dec->Open("file:///tmp/sample.wav"));
  PcmBuffer buf;
  EXPECT_FALSE(dec->Read(buf));  // EOF
  EXPECT_EQ(buf.sample_rate, 44100);
  EXPECT_EQ(buf.channels, 1);
  EXPECT_EQ(dec->sample_rate(), 44100);
  EXPECT_EQ(dec->channels(), 1);
  EXPECT_EQ(dec->last_status(), Status::kOk);
}

TEST(DecoderStubTest, ConfigureOutputRejectsInvalid) {
  std::unique_ptr<Decoder> dec = CreateStubDecoder();
  EXPECT_FALSE(dec->ConfigureOutput(-1, 0));
  EXPECT_EQ(dec->last_status(), Status::kInvalidArguments);
}

}  // namespace sw
