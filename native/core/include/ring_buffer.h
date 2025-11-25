#pragma once

#include <cstddef>
#include <memory>

namespace sw {

// Lock-safe ring buffer for interleaved PCM frames (single producer/consumer focused).
class RingBuffer {
 public:
  // capacity_frames: number of PCM frames (per channel) the buffer can hold.
  RingBuffer(size_t capacity_frames, int channels);
  ~RingBuffer();

  RingBuffer(const RingBuffer&) = delete;
  RingBuffer& operator=(const RingBuffer&) = delete;
  RingBuffer(RingBuffer&&) noexcept;
  RingBuffer& operator=(RingBuffer&&) noexcept;

  size_t capacity_frames() const;
  int channels() const;

  // Number of frames currently buffered/available to read.
  size_t readable_frames() const;
  // Number of frames that can be written without overwriting unread data.
  size_t writable_frames() const;

  bool empty() const;
  bool full() const;

  // Attempts to write up to |frames| frames (interleaved) into the buffer.
  // Returns the number of frames actually written (may be partial if full).
  size_t Write(const float* interleaved, size_t frames);

  // Attempts to read up to |frames| frames (interleaved) from the buffer.
  // Returns the number of frames actually read (0 if empty).
  size_t Read(float* interleaved_out, size_t frames);

  // Drops all buffered data.
  void Clear();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace sw
