#include "decoder.h"

#include <algorithm>

namespace sw {

class DecoderStub : public Decoder {
 public:
  bool Open(const std::string& source) override {
    if (source.empty()) {
      return false;
    }
    if (!IsSupported(source)) {
      return false;
    }
    opened_ = true;
    return true;
  }
  bool Read(PcmBuffer& out_buffer) override {
    if (!opened_) {
      return false;
    }
    out_buffer.interleaved.clear();
    out_buffer.sample_rate = 48000;
    out_buffer.channels = 2;
    return false;  // EOF immediately.
  }
  void Close() override {}

  int sample_rate() const override { return 48000; }
  int channels() const override { return 2; }

 private:
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
};

std::unique_ptr<Decoder> CreateStubDecoder() {
  return std::make_unique<DecoderStub>();
}

}  // namespace sw
