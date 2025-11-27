#pragma once

#include <cstdint>
#include <vector>

namespace sw {

struct PcmThrottleConfig {
  // 目标最大推送帧率（每秒帧数），用于限频。
  int max_fps = 60;
  // 队列上限（单位：帧），超过后需抽稀/丢弃并记录。
  size_t max_pending = 4;
};

struct PcmThrottleInput {
  uint32_t sequence = 0;
  int64_t timestamp_ms = 0;
  int num_frames = 0;
  int num_channels = 0;
};

struct PcmThrottleOutput {
  uint32_t sequence = 0;
  int64_t timestamp_ms = 0;
  // 在本帧之前累计丢弃/抽稀的帧数，用于上层监控。
  uint32_t dropped_before = 0;
  // true 表示这是一个“丢帧标记”占位（无实际 PCM 数据）。
  bool dropped = false;
};

// 节流器：根据配置限频/限帧，输出透传帧及丢帧标记。
class PcmThrottler {
 public:
  explicit PcmThrottler(const PcmThrottleConfig& config);

  // 处理一帧输入，返回需推送给上层的帧/标记（0 或 1 个元素）。
  std::vector<PcmThrottleOutput> Push(const PcmThrottleInput& input, int64_t now_ms);

  void Reset();

 private:
  PcmThrottleConfig config_;
  int64_t last_emit_ms_ = -1;
  uint32_t pending_drops_ = 0;
  int pending_kept_ = 0;
};

}  // namespace sw
