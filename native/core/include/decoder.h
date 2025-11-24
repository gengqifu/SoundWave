#pragma once

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace sw {

struct PcmBuffer {
  std::vector<float> interleaved;  // interleaved float32
  int sample_rate = 0;
  int channels = 0;
};

class Decoder {
 public:
  virtual ~Decoder() = default;

  // Returns true on open success; false on error (e.g., not found, not supported).
  virtual bool Open(const std::string& source) = 0;
  // Returns true if a frame is read; false on EOF or error.
  virtual bool Read(PcmBuffer& out_buffer) = 0;
  virtual void Close() = 0;

  virtual int sample_rate() const = 0;
  virtual int channels() const = 0;
};

std::unique_ptr<Decoder> CreateStubDecoder();

}  // namespace sw
