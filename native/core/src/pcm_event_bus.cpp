#include "pcm_event_bus.h"

#include <algorithm>
#include <memory>

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
  SpectrumConfig cfg = spectrum_cfg_;
  cfg.window_size =
      cfg.window_size > 0 ? std::min(cfg.window_size, frame.num_frames) : frame.num_frames;
  if (cfg.window_size <= 0 || frame.data == nullptr || frame.num_channels <= 0) return;

  auto mono = DownmixToMono(frame.data, frame.num_frames, frame.num_channels, cfg.window_size);
  cfg.window_size = static_cast<int>(mono.size());
  if (mono.empty()) return;

  auto spectrum = ComputeSpectrum(mono, frame.sample_rate, cfg);
  if (spectrum.empty()) return;

  auto bins = std::make_shared<std::vector<float>>(std::move(spectrum));
  SpectrumFrame spec;
  spec.bins = bins->data();
  spec.num_bins = static_cast<int>(bins->size());
  spec.window_size = cfg.window_size;
  spec.bin_hz = frame.sample_rate > 0 ? static_cast<float>(frame.sample_rate) / cfg.window_size
                                      : 0.0f;
  spec.sample_rate = frame.sample_rate;
  spec.window = cfg.window;
  spec.power_spectrum = cfg.power_spectrum;
  spec.timestamp_ms = frame.timestamp_ms;
  spectrum_cb_(spec);
}

void PcmEventBus::Reset() {
  ingress_.Reset();
  spectrum_seq_ = 0;
}

}  // namespace sw
