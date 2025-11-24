#include "decoder.h"

#include <algorithm>

namespace sw {

class DecoderStub : public Decoder {
 public:
  bool Open(const std::string& source) override {
    if (source.empty()) {
      last_status_ = Status::kInvalidArguments;
      return false;
    }
    if (IsMissing(source)) {
      last_status_ = Status::kIoError;
      return false;
    }
    if (IsDecodeFailure(source)) {
      last_status_ = Status::kError;
      return false;
    }
    if (!IsSupported(source)) {
      last_status_ = Status::kNotSupported;
      return false;
    }
    opened_ = true;
    last_status_ = Status::kOk;
    source_ = source;
    return true;
  }
  bool Read(PcmBuffer& out_buffer) override {
    if (!opened_) {
      last_status_ = Status::kInvalidState;
      return false;
    }
    out_buffer.interleaved.clear();
    out_buffer.sample_rate = sample_rate_;
    out_buffer.channels = channels_;
    last_status_ = Status::kOk;
    return false;  // EOF immediately.
  }
  void Close() override {
    opened_ = false;
    source_.clear();
  }

  int sample_rate() const override { return sample_rate_; }
  int channels() const override { return channels_; }

  bool ConfigureOutput(int target_sample_rate, int target_channels) override {
    if (target_sample_rate <= 0 || target_channels <= 0) {
      last_status_ = Status::kInvalidArguments;
      return false;
    }
    sample_rate_ = target_sample_rate;
    channels_ = target_channels;
    last_status_ = Status::kOk;
    return true;
  }

  Status last_status() const override { return last_status_; }

 private:
  bool IsMissing(const std::string& src) const { return src.find("missing") != std::string::npos; }

  bool IsDecodeFailure(const std::string& src) const {
    return src.find("decodefail") != std::string::npos;
  }

  bool IsSupported(const std::string& src) const {
    auto dot = src.find_last_of('.');
    if (dot == std::string::npos || dot + 1 >= src.size()) {
      return false;
    }
    std::string ext = src.substr(dot + 1);
    std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
    return ext == "mp3" || ext == "aac" || ext == "m4a" || ext == "wav" || ext == "flac";
  }

  bool opened_ = false;
  int sample_rate_ = 48000;
  int channels_ = 2;
  std::string source_;
  Status last_status_ = Status::kOk;
};

std::unique_ptr<Decoder> CreateStubDecoder() {
  return std::make_unique<DecoderStub>();
}

}  // namespace sw
