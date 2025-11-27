#include "pcm_throttler.h"

namespace sw {

PcmThrottler::PcmThrottler(const PcmThrottleConfig& config) : config_(config) {}

std::vector<PcmThrottleOutput> PcmThrottler::Push(const PcmThrottleInput& input, int64_t now_ms) {
  std::vector<PcmThrottleOutput> out;

  if (config_.max_pending <= 0) {
    return out;
  }

  const int min_interval_ms =
      config_.max_fps > 0 ? static_cast<int>(1000 / config_.max_fps) : 0;

  const bool should_emit =
      last_emit_ms_ < 0 || min_interval_ms <= 0 ||
      (now_ms - last_emit_ms_) >= min_interval_ms;

  if (should_emit) {
    out.push_back(PcmThrottleOutput{
        input.sequence,
        input.timestamp_ms,
        pending_drops_,
        /*dropped=*/false,
    });
    pending_drops_ = 0;
    pending_kept_ = 0;
    last_emit_ms_ = now_ms;
  } else {
    // 未到间隔：优先排队，超过上限则丢弃并发出 dropped 标记。
    if (pending_kept_ < static_cast<int>(config_.max_pending)) {
      pending_kept_++;
    } else {
      pending_drops_++;
      out.push_back(PcmThrottleOutput{
          input.sequence,
          input.timestamp_ms,
          pending_drops_,
          /*dropped=*/true,
      });
    }
  }

  return out;
}

void PcmThrottler::Reset() {
  last_emit_ms_ = -1;
  pending_drops_ = 0;
  pending_kept_ = 0;
}

}  // namespace sw
