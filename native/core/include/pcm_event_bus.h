#pragma once

#include <cstdint>
#include <functional>
#include <memory>
#include <vector>

#include "audio_engine.h"
#include "pcm_ingress.h"

namespace sw {

// 负责将上层推送的 PCM 经过校验/节流后分发波形与频谱事件（频谱可占位）。
class PcmEventBus {
 public:
  using PcmCallback = std::function<void(const PcmFrame&)>;
  using SpectrumCallback = std::function<void(const SpectrumFrame&)>;

  PcmEventBus(const PcmIngressConfig& ingress_cfg, const SpectrumConfig& spectrum_cfg);

  // 推送一帧 PCM，now_ms 为当前时间（用于节流）；返回状态。
  Status Push(const PcmInputFrame& frame, int64_t now_ms);

  void SetPcmCallback(PcmCallback cb) { pcm_cb_ = std::move(cb); }
  void SetSpectrumCallback(SpectrumCallback cb) { spectrum_cb_ = std::move(cb); }

  void Reset();

 private:
  PcmIngress ingress_;
  SpectrumConfig spectrum_cfg_;
  PcmCallback pcm_cb_;
  SpectrumCallback spectrum_cb_;
  uint32_t spectrum_seq_ = 0;

  void EmitSpectrumIfNeeded(const PcmFrame& frame);
};

}  // namespace sw
