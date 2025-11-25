#include "ring_buffer.h"

#include <algorithm>
#include <mutex>
#include <vector>

namespace sw {

struct RingBuffer::Impl {
  size_t capacity_frames = 0;
  int channels = 0;
  size_t read_pos = 0;
  size_t write_pos = 0;
  size_t size_frames = 0;
  std::vector<float> storage;
  mutable std::mutex mu;
};

RingBuffer::RingBuffer(size_t capacity_frames, int channels) : impl_(std::make_unique<Impl>()) {
  impl_->capacity_frames = capacity_frames;
  impl_->channels = std::max(1, channels);
  impl_->storage.resize(capacity_frames * static_cast<size_t>(impl_->channels));
}

RingBuffer::~RingBuffer() = default;

RingBuffer::RingBuffer(RingBuffer&& other) noexcept = default;
RingBuffer& RingBuffer::operator=(RingBuffer&& other) noexcept = default;

size_t RingBuffer::capacity_frames() const { return impl_->capacity_frames; }

int RingBuffer::channels() const { return impl_->channels; }

size_t RingBuffer::readable_frames() const {
  std::lock_guard<std::mutex> lock(impl_->mu);
  return impl_->size_frames;
}

size_t RingBuffer::writable_frames() const {
  std::lock_guard<std::mutex> lock(impl_->mu);
  return impl_->capacity_frames - impl_->size_frames;
}

bool RingBuffer::empty() const { return readable_frames() == 0; }

bool RingBuffer::full() const { return readable_frames() >= impl_->capacity_frames; }

size_t RingBuffer::Write(const float* interleaved, size_t frames) {
  if (!interleaved || frames == 0 || impl_->capacity_frames == 0) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(impl_->mu);
  const size_t writable = impl_->capacity_frames - impl_->size_frames;
  const size_t to_write = std::min(frames, writable);
  if (to_write == 0) {
    return 0;
  }

  const int ch = impl_->channels;
  const size_t cap = impl_->capacity_frames;

  size_t first = std::min(to_write, cap - impl_->write_pos);
  for (size_t i = 0; i < first; ++i) {
    const size_t dst_frame = impl_->write_pos + i;
    const size_t dst_offset = dst_frame * ch;
    const size_t src_offset = i * ch;
    for (int c = 0; c < ch; ++c) {
      impl_->storage[dst_offset + c] = interleaved[src_offset + c];
    }
  }

  size_t second = to_write - first;
  if (second > 0) {
    for (size_t i = 0; i < second; ++i) {
      const size_t dst_frame = i;
      const size_t dst_offset = dst_frame * ch;
      const size_t src_offset = (first + i) * ch;
      for (int c = 0; c < ch; ++c) {
        impl_->storage[dst_offset + c] = interleaved[src_offset + c];
      }
    }
  }

  impl_->write_pos = (impl_->write_pos + to_write) % cap;
  impl_->size_frames += to_write;
  return to_write;
}

size_t RingBuffer::Read(float* interleaved_out, size_t frames) {
  if (!interleaved_out || frames == 0 || impl_->capacity_frames == 0) {
    return 0;
  }
  std::lock_guard<std::mutex> lock(impl_->mu);
  const size_t readable = impl_->size_frames;
  const size_t to_read = std::min(frames, readable);
  if (to_read == 0) {
    return 0;
  }

  const int ch = impl_->channels;
  const size_t cap = impl_->capacity_frames;

  size_t first = std::min(to_read, cap - impl_->read_pos);
  for (size_t i = 0; i < first; ++i) {
    const size_t src_frame = impl_->read_pos + i;
    const size_t src_offset = src_frame * ch;
    const size_t dst_offset = i * ch;
    for (int c = 0; c < ch; ++c) {
      interleaved_out[dst_offset + c] = impl_->storage[src_offset + c];
    }
  }

  size_t second = to_read - first;
  if (second > 0) {
    for (size_t i = 0; i < second; ++i) {
      const size_t src_frame = i;
      const size_t src_offset = src_frame * ch;
      const size_t dst_offset = (first + i) * ch;
      for (int c = 0; c < ch; ++c) {
        interleaved_out[dst_offset + c] = impl_->storage[src_offset + c];
      }
    }
  }

  impl_->read_pos = (impl_->read_pos + to_read) % cap;
  impl_->size_frames -= to_read;
  return to_read;
}

void RingBuffer::Clear() {
  std::lock_guard<std::mutex> lock(impl_->mu);
  impl_->read_pos = 0;
  impl_->write_pos = 0;
  impl_->size_frames = 0;
}

}  // namespace sw
