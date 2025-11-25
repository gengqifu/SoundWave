#include "ring_buffer.h"

#include <gtest/gtest.h>

#include <atomic>
#include <chrono>
#include <cstddef>
#include <thread>
#include <vector>

using namespace std::chrono_literals;

namespace sw {

TEST(RingBufferTest, TracksCapacityAndFullEmptyStates) {
  RingBuffer buffer(4, 2);
  EXPECT_EQ(buffer.capacity_frames(), 4u);
  EXPECT_EQ(buffer.channels(), 2);
  EXPECT_TRUE(buffer.empty());
  EXPECT_FALSE(buffer.full());
  EXPECT_EQ(buffer.readable_frames(), 0u);
  EXPECT_EQ(buffer.writable_frames(), 4u);

  std::vector<float> frames = {0, 1, 2, 3};
  EXPECT_EQ(buffer.Write(frames.data(), 2), 2u);
  EXPECT_FALSE(buffer.empty());
  EXPECT_EQ(buffer.readable_frames(), 2u);
  EXPECT_EQ(buffer.writable_frames(), 2u);

  // Fill to capacity; extra writes should be dropped/partial.
  EXPECT_EQ(buffer.Write(frames.data(), 4), 2u);
  EXPECT_TRUE(buffer.full());
  EXPECT_EQ(buffer.readable_frames(), 4u);
  EXPECT_EQ(buffer.writable_frames(), 0u);

  std::vector<float> out(6, -1.0f);
  EXPECT_EQ(buffer.Read(out.data(), 3), 3u);
  EXPECT_FALSE(buffer.full());
  EXPECT_EQ(buffer.readable_frames(), 1u);
  EXPECT_EQ(buffer.writable_frames(), 3u);

  buffer.Clear();
  EXPECT_TRUE(buffer.empty());
  EXPECT_EQ(buffer.readable_frames(), 0u);
  EXPECT_EQ(buffer.writable_frames(), 4u);
}

TEST(RingBufferTest, WrapAroundPreservesOrder) {
  RingBuffer buffer(4, 1);
  float first[] = {1.0f, 2.0f, 3.0f};
  ASSERT_EQ(buffer.Write(first, 3), 3u);

  float partial[2] = {};
  ASSERT_EQ(buffer.Read(partial, 2), 2u);
  EXPECT_FLOAT_EQ(partial[0], 1.0f);
  EXPECT_FLOAT_EQ(partial[1], 2.0f);

  float second[] = {4.0f, 5.0f, 6.0f};
  ASSERT_EQ(buffer.Write(second, 3), 3u);  // should wrap internally.

  float drained[4] = {};
  ASSERT_EQ(buffer.Read(drained, 4), 4u);
  EXPECT_FLOAT_EQ(drained[0], 3.0f);
  EXPECT_FLOAT_EQ(drained[1], 4.0f);
  EXPECT_FLOAT_EQ(drained[2], 5.0f);
  EXPECT_FLOAT_EQ(drained[3], 6.0f);
  EXPECT_TRUE(buffer.empty());
}

TEST(RingBufferTest, ConcurrentProducerConsumerMaintainsOrder) {
  RingBuffer buffer(512, 2);
  const size_t total_frames = 4096;
  const auto deadline = std::chrono::steady_clock::now() + 2s;

  std::atomic<size_t> produced{0};
  std::atomic<size_t> consumed{0};
  std::atomic<size_t> mismatches{0};

  std::thread producer([&]() {
    std::vector<float> chunk(buffer.channels() * 64);
    while (produced.load() < total_frames && std::chrono::steady_clock::now() < deadline) {
      const size_t base = produced.load();
      const size_t to_write = std::min<size_t>(64, total_frames - base);
      for (size_t i = 0; i < to_write; ++i) {
        const float v = static_cast<float>(base + i);
        for (int ch = 0; ch < buffer.channels(); ++ch) {
          chunk[i * buffer.channels() + ch] = v;
        }
      }
      size_t wrote = buffer.Write(chunk.data(), to_write);
      if (wrote == 0) {
        std::this_thread::yield();
        continue;
      }
      produced.fetch_add(wrote);
    }
  });

  std::thread consumer([&]() {
    std::vector<float> chunk(buffer.channels() * 64);
    while (consumed.load() < total_frames && std::chrono::steady_clock::now() < deadline) {
      size_t got = buffer.Read(chunk.data(), 64);
      if (got == 0) {
        std::this_thread::yield();
        continue;
      }
      const size_t start = consumed.load();
      for (size_t i = 0; i < got; ++i) {
        const float expected = static_cast<float>(start + i);
        for (int ch = 0; ch < buffer.channels(); ++ch) {
          const float sample = chunk[i * buffer.channels() + ch];
          if (sample != expected) {
            mismatches.fetch_add(1);
          }
        }
      }
      consumed.fetch_add(got);
    }
  });

  producer.join();
  consumer.join();

  EXPECT_LT(std::chrono::steady_clock::now(), deadline) << "Producer/consumer stalled";
  EXPECT_EQ(consumed.load(), total_frames);
  EXPECT_EQ(mismatches.load(), 0u);
  EXPECT_TRUE(buffer.empty());
}

TEST(RingBufferTest, PerformanceSmokeLargeBursts) {
  RingBuffer buffer(2048, 2);
  const size_t total_frames = 50000;
  const auto deadline = std::chrono::steady_clock::now() + 2s;

  size_t produced = 0;
  size_t consumed = 0;
  std::vector<float> write_chunk(buffer.channels() * 256, 0.25f);
  std::vector<float> read_chunk(buffer.channels() * 512, 0.0f);

  while (produced < total_frames && std::chrono::steady_clock::now() < deadline) {
    const size_t to_write = std::min<size_t>(256, total_frames - produced);
    size_t wrote = buffer.Write(write_chunk.data(), to_write);
    if (wrote == 0) {
      buffer.Read(read_chunk.data(), 128);  // drain to unblock.
      continue;
    }
    produced += wrote;
    consumed += buffer.Read(read_chunk.data(), 128);
  }

  while (consumed < produced && std::chrono::steady_clock::now() < deadline) {
    size_t r = buffer.Read(read_chunk.data(), 512);
    if (r == 0) {
      std::this_thread::yield();
      continue;
    }
    consumed += r;
  }

  EXPECT_LT(std::chrono::steady_clock::now(), deadline) << "Performance smoke timed out";
  EXPECT_EQ(consumed, produced);
  EXPECT_TRUE(buffer.empty());
}

}  // namespace sw
