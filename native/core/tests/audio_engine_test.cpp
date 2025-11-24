#include "audio_engine.h"
#include "decoder.h"

#include <gtest/gtest.h>
#include <filesystem>
#include <fstream>
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

TEST(DecoderStubTest, RepeatedOpenReadCloseDoesNotCrash) {
  std::unique_ptr<Decoder> dec = CreateStubDecoder();
  for (int i = 0; i < 200; ++i) {
    ASSERT_TRUE(dec->Open("file:///tmp/sample.wav"));
    PcmBuffer buf;
    dec->Read(buf);
    dec->Close();
  }
  // No explicit leak check here; test ensures stability across many iterations.
}

#ifdef SW_ENABLE_FFMPEG
namespace {
std::optional<std::string> FindSample(const std::string& name) {
  // Look under repo ffmpeg/testdata/ or native/core/tests/data/.
  const std::vector<std::filesystem::path> roots = {
      std::filesystem::path(__FILE__).parent_path() / "data",
      std::filesystem::path(__FILE__).parent_path().parent_path().parent_path() / "ffmpeg" /
          "testdata"};
  for (const auto& root : roots) {
    auto p = root / name;
    if (std::filesystem::exists(p)) {
      return p.string();
    }
  }
  return std::nullopt;
}

std::string WriteTinyWav(const std::string& filename) {
  // Minimal PCM s16le mono wav with a few samples of silence.
  const int sample_rate = 16000;
  const int channels = 1;
  const int16_t samples[] = {0, 0, 0, 0, 0, 0};
  const int num_samples = static_cast<int>(sizeof(samples) / sizeof(samples[0]));
  const int bytes_per_sample = sizeof(int16_t);
  const int data_size = num_samples * bytes_per_sample * channels;
  const int fmt_chunk_size = 16;
  const int audio_format = 1;  // PCM
  const int byte_rate = sample_rate * channels * bytes_per_sample;
  const int block_align = channels * bytes_per_sample;
  const int bits_per_sample = 8 * bytes_per_sample;
  const int riff_chunk_size = 4 /*WAVE*/ + 8 + fmt_chunk_size + 8 + data_size;

  std::filesystem::path path = std::filesystem::temp_directory_path() / filename;
  std::ofstream out(path, std::ios::binary);
  // RIFF header
  out.write("RIFF", 4);
  int32_t chunk_size_le = riff_chunk_size;
  out.write(reinterpret_cast<const char*>(&chunk_size_le), 4);
  out.write("WAVE", 4);
  // fmt subchunk
  out.write("fmt ", 4);
  int32_t fmt_size_le = fmt_chunk_size;
  out.write(reinterpret_cast<const char*>(&fmt_size_le), 4);
  int16_t audio_fmt_le = audio_format;
  int16_t num_channels_le = channels;
  int32_t sample_rate_le = sample_rate;
  int32_t byte_rate_le = byte_rate;
  int16_t block_align_le = block_align;
  int16_t bits_per_sample_le = bits_per_sample;
  out.write(reinterpret_cast<const char*>(&audio_fmt_le), 2);
  out.write(reinterpret_cast<const char*>(&num_channels_le), 2);
  out.write(reinterpret_cast<const char*>(&sample_rate_le), 4);
  out.write(reinterpret_cast<const char*>(&byte_rate_le), 4);
  out.write(reinterpret_cast<const char*>(&block_align_le), 2);
  out.write(reinterpret_cast<const char*>(&bits_per_sample_le), 2);
  // data subchunk
  out.write("data", 4);
  int32_t data_size_le = data_size;
  out.write(reinterpret_cast<const char*>(&data_size_le), 4);
  out.write(reinterpret_cast<const char*>(samples), data_size);
  out.close();
  return path.string();
}
}  // namespace

TEST(DecoderFFmpegTest, DecodeTinyWavSuccess) {
  std::string wav_path = WriteTinyWav("soundwave_ffmpeg_test.wav");
  std::unique_ptr<Decoder> dec = CreateFFmpegDecoder();
  ASSERT_TRUE(dec->ConfigureOutput(16000, 1));
  ASSERT_TRUE(dec->Open(wav_path));
  PcmBuffer buf;
  bool got_frame = false;
  while (dec->Read(buf)) {
    if (!buf.interleaved.empty()) {
      got_frame = true;
      break;
    }
  }
  EXPECT_TRUE(got_frame);
  EXPECT_EQ(buf.sample_rate, 16000);
  EXPECT_EQ(buf.channels, 1);
  EXPECT_EQ(dec->last_status(), Status::kOk);
}

TEST(DecoderFFmpegTest, MissingFileReturnsIoError) {
  std::unique_ptr<Decoder> dec = CreateFFmpegDecoder();
  EXPECT_FALSE(dec->Open("/tmp/soundwave_ffmpeg_missing.wav"));
  EXPECT_EQ(dec->last_status(), Status::kIoError);
}

TEST(DecoderFFmpegTest, DecodeMp3IfPresent) {
  auto path = FindSample("sample.mp3");
  if (!path) {
    GTEST_SKIP() << "mp3 sample not found";
  }
  std::unique_ptr<Decoder> dec = CreateFFmpegDecoder();
  ASSERT_TRUE(dec->Open(*path));
  PcmBuffer buf;
  bool got_frame = false;
  while (dec->Read(buf)) {
    if (!buf.interleaved.empty()) {
      got_frame = true;
      break;
    }
  }
  EXPECT_TRUE(got_frame);
  EXPECT_GT(buf.sample_rate, 0);
  EXPECT_GE(buf.channels, 1);
}

TEST(DecoderFFmpegTest, DecodeAacIfPresent) {
  auto path = FindSample("sample.aac");
  if (!path) {
    GTEST_SKIP() << "aac sample not found";
  }
  std::unique_ptr<Decoder> dec = CreateFFmpegDecoder();
  ASSERT_TRUE(dec->Open(*path));
  PcmBuffer buf;
  bool got_frame = false;
  while (dec->Read(buf)) {
    if (!buf.interleaved.empty()) {
      got_frame = true;
      break;
    }
  }
  EXPECT_TRUE(got_frame);
  EXPECT_GT(buf.sample_rate, 0);
  EXPECT_GE(buf.channels, 1);
}

TEST(DecoderFFmpegTest, DecodeFlacIfPresent) {
  auto path = FindSample("sample.flac");
  if (!path) {
    GTEST_SKIP() << "flac sample not found";
  }
  std::unique_ptr<Decoder> dec = CreateFFmpegDecoder();
  ASSERT_TRUE(dec->Open(*path));
  PcmBuffer buf;
  bool got_frame = false;
  while (dec->Read(buf)) {
    if (!buf.interleaved.empty()) {
      got_frame = true;
      break;
    }
  }
  EXPECT_TRUE(got_frame);
  EXPECT_GT(buf.sample_rate, 0);
  EXPECT_GE(buf.channels, 1);
}

TEST(DecoderFFmpegTest, CorruptFileReturnsError) {
  std::filesystem::path corrupt =
      std::filesystem::temp_directory_path() / "soundwave_ffmpeg_corrupt.bin";
  {
    std::ofstream out(corrupt, std::ios::binary);
    out << "NOT_A_MEDIA_FILE";
  }
  std::unique_ptr<Decoder> dec = CreateFFmpegDecoder();
  ASSERT_TRUE(dec->ConfigureOutput(16000, 2));
  EXPECT_FALSE(dec->Open(corrupt.string()));
  // IoError when cannot parse header; could also be kError depending on FFmpeg code paths.
  EXPECT_TRUE(dec->last_status() == Status::kIoError || dec->last_status() == Status::kError);
  std::filesystem::remove(corrupt);
}
#endif  // SW_ENABLE_FFMPEG

}  // namespace sw
