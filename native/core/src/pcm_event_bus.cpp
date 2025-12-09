#include "pcm_event_bus.h"

#include <algorithm>

namespace sw {

PcmEventBus::PcmEventBus(const PcmIngressConfig& ingress_cfg, const SpectrumConfig& spectrum_cfg)
    : ingress_(ingress_cfg), spectrum_cfg_(spectrum_cfg) {}

Status PcmEventBus::Push(const PcmInputFrame& frame, int64_t now_ms) {
  auto st = ingress_.Push(frame, now_ms);
  if (st != Status::kOk) return st;

  PcmFrame out;
  while (ingress_.Pop(out)) {
    if (pcm_cb_) {
      pcm_cb_(out);
    }
    if (spectrum_cb_ && !out.dropped) {
      EmitSpectrumIfNeeded(out);
    }
  }
  return Status::kOk;
}

void PcmEventBus::EmitSpectrumIfNeeded(const PcmFrame& frame) {
  const int window = spectrum_cfg_.window_size > 0
                         ? std::min(spectrum_cfg_.window_size, frame.num_frames)
                         : frame.num_frames;
  if (window <= 0 || frame.data == nullptr || frame.num_channels <= 0) return;
  // 简化：占位谱（零），长度 = window/2+1。
  const int num_bins = window / 2 + 1;
  auto bins = std::make_shared<std::vector<float>>(static_cast<size_t>(num_bins), 0.0f);

  SpectrumFrame spec;
  spec.bins = bins->data();
  spec.num_bins = num_bins;
  spec.window_size = window;
  spec.bin_hz = frame.sample_rate > 0 ? static_cast<float>(frame.sample_rate) / window : 0.0f;
  spec.sample_rate = frame.sample_rate;
  spec.window = spectrum_cfg_.window;
  spec.power_spectrum = spectrum_cfg_.power_spectrum;
  spec.timestamp_ms = frame.timestamp_ms;
  spectrum_cb_(spec);
}

void PcmEventBus::Reset() {
  ingress_.Reset();
  spectrum_seq_ = 0;
}

}  // namespace sw
