#include "pcm_throttler.h"

#include <gtest/gtest.h>

#include <vector>

using namespace std::chrono_literals;

namespace sw {

TEST(PcmThrottleTest, EnforcesMaxFpsAndAggregatesDrops) {
  PcmThrottleConfig cfg;
  cfg.max_fps = 50;       // 最小间隔 20ms
  cfg.max_pending = 4;    // 队列上限
  PcmThrottler throttler(cfg);

  std::vector<PcmThrottleOutput> emitted;
  const int64_t timestamps_ms[] = {0, 5, 10, 15, 20, 25};
  uint32_t seq = 1;
  for (int64_t ts : timestamps_ms) {
    PcmThrottleInput in;
    in.sequence = seq++;
    in.timestamp_ms = ts;
    in.num_frames = 128;
    in.num_channels = 2;
    auto out = throttler.Push(in, ts);
    emitted.insert(emitted.end(), out.begin(), out.end());
  }

  ASSERT_EQ(emitted.size(), 2u);
  EXPECT_EQ(emitted[0].sequence, 1u);
  EXPECT_EQ(emitted[0].dropped_before, 0u);

  EXPECT_EQ(emitted[1].sequence, 5u);  // 第 5 帧才满足 20ms 间隔
  // 帧 2-4 在队列等待，不计为丢弃。
  EXPECT_EQ(emitted[1].dropped_before, 0u);
}

TEST(PcmThrottleTest, DropsExcessPendingAndReports) {
  PcmThrottleConfig cfg;
  cfg.max_fps = 50;       // 20ms 间隔
  cfg.max_pending = 2;    // 仅保留 2 帧
  PcmThrottler throttler(cfg);

  std::vector<PcmThrottleOutput> emitted;
  // 前四帧在 0ms 内过快到达，将被聚合为丢帧计数；第 5 帧在 20ms 触发输出。
  const int64_t timestamps_ms[] = {0, 0, 0, 0, 20};
  for (uint32_t i = 0; i < 5; ++i) {
    PcmThrottleInput in;
    in.sequence = i + 1;
    in.timestamp_ms = timestamps_ms[i];
    in.num_frames = 128;
    in.num_channels = 1;
    auto out = throttler.Push(in, timestamps_ms[i]);
    emitted.insert(emitted.end(), out.begin(), out.end());
  }

  ASSERT_EQ(emitted.size(), 3u);
  EXPECT_EQ(emitted[0].sequence, 1u);
  EXPECT_EQ(emitted[0].dropped_before, 0u);
  EXPECT_FALSE(emitted[0].dropped);

  // 第 4 帧溢出 pending，生成 dropped 标记（丢弃 1 帧）。
  EXPECT_TRUE(emitted[1].dropped);
  EXPECT_EQ(emitted[1].sequence, 4u);
  EXPECT_EQ(emitted[1].dropped_before, 1u);

  // 第 5 帧满足间隔，仅携带真实丢弃的 1 帧。
  EXPECT_FALSE(emitted[2].dropped);
  EXPECT_EQ(emitted[2].sequence, 5u);
  EXPECT_EQ(emitted[2].dropped_before, 1u);
}

}  // namespace sw
