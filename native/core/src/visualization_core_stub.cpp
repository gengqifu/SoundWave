#include "visualization_core_stub.h"

#include <atomic>
#include <cmath>
#include <memory>
#include <thread>
#include <vector>

namespace sw {

struct VisStubHandle {
  VisStubConfig cfg;
  std::unique_ptr<PcmThrottler> pcm_throttler;
  std::unique_ptr<PcmThrottler> spectrum_throttler;
  std::atomic<bool> running{false};
  std::thread worker;

  void (*pcm_cb)(const PcmFrame&, void*) = nullptr;
  void* pcm_ud = nullptr;
  void (*spectrum_cb)(const SpectrumFrame&, void*) = nullptr;
  void* spectrum_ud = nullptr;
};

static void RunLoop(VisStubHandle* h) {
  const size_t frames_per_buf = static_cast<size_t>(h->cfg.frames_per_buffer);
  const size_t ch = static_cast<size_t>(h->cfg.channels);
  const float sr = static_cast<float>(h->cfg.sample_rate);
  std::vector<float> interleaved(frames_per_buf * ch, 0.0f);
  float phase = 0.0f;
  const float tone = 1000.0f;
  const float two_pi = 2.0f * static_cast<float>(M_PI);
  int64_t ts_ms = 0;
  const int64_t frame_dur_ms =
      static_cast<int64_t>((frames_per_buf * 1000) / static_cast<size_t>(h->cfg.sample_rate));

  while (h->running.load()) {
    // 填充合成正弦，双声道同相
    for (size_t i = 0; i < frames_per_buf; ++i) {
      float sample = std::sin(two_pi * tone * (static_cast<float>(i) / sr) + phase);
      for (size_t c = 0; c < ch; ++c) {
        interleaved[i * ch + c] = sample;
      }
    }
    phase += two_pi * tone * static_cast<float>(frames_per_buf) / sr;

    // PCM 推送（节流）
    if (h->pcm_cb && h->pcm_throttler) {
      PcmThrottleInput in;
      in.sequence = 0;  // 不关心序号
      in.timestamp_ms = ts_ms;
      in.num_frames = static_cast<int>(frames_per_buf);
      in.num_channels = static_cast<int>(ch);
      auto outs = h->pcm_throttler->Push(in, ts_ms);
      for (const auto& o : outs) {
        if (o.dropped) continue;
        PcmFrame f;
        f.data = interleaved.data();
        f.num_frames = in.num_frames;
        f.num_channels = in.num_channels;
        f.sample_rate = h->cfg.sample_rate;
        f.timestamp_ms = o.timestamp_ms;
        h->pcm_cb(f, h->pcm_ud);
      }
    }

    // 频谱推送（节流）
    if (h->spectrum_cb && h->spectrum_throttler) {
      PcmThrottleInput in;
      in.sequence = 0;
      in.timestamp_ms = ts_ms;
      in.num_frames = static_cast<int>(frames_per_buf);
      in.num_channels = static_cast<int>(ch);
      auto outs = h->spectrum_throttler->Push(in, ts_ms);
      for (const auto& o : outs) {
        if (o.dropped) continue;
        SpectrumConfig scfg = h->cfg.spectrum_cfg;
        if (scfg.window_size <= 0 || scfg.window_size > static_cast<int>(frames_per_buf)) {
          scfg.window_size = static_cast<int>(frames_per_buf);
        }
        std::vector<float> mono(static_cast<size_t>(scfg.window_size));
        for (int i = 0; i < scfg.window_size; ++i) {
          mono[static_cast<size_t>(i)] = interleaved[static_cast<size_t>(i * ch)];
        }
        auto spec = ComputeSpectrum(mono, h->cfg.sample_rate, scfg);
        if (spec.empty()) continue;
        SpectrumFrame sf;
        sf.bins = spec.data();
        sf.num_bins = static_cast<int>(spec.size());
        sf.window_size = scfg.window_size;
        sf.bin_hz = static_cast<float>(h->cfg.sample_rate) /
                    static_cast<float>(scfg.window_size);
        sf.sample_rate = h->cfg.sample_rate;
        sf.window = scfg.window;
        sf.power_spectrum = scfg.power_spectrum;
        sf.timestamp_ms = o.timestamp_ms;
        h->spectrum_cb(sf, h->spectrum_ud);
      }
    }

    ts_ms += frame_dur_ms;
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }
}

VisStubHandle* vis_stub_create(const VisStubConfig& cfg) {
  auto h = new VisStubHandle();
  h->cfg = cfg;
  PcmThrottleConfig pcm_cfg;
  pcm_cfg.max_fps = cfg.pcm_max_fps;
  h->pcm_throttler = std::make_unique<PcmThrottler>(pcm_cfg);
  PcmThrottleConfig spec_cfg;
  spec_cfg.max_fps = cfg.spectrum_max_fps;
  h->spectrum_throttler = std::make_unique<PcmThrottler>(spec_cfg);
  return h;
}

void vis_stub_destroy(VisStubHandle* handle) {
  if (!handle) return;
  vis_stub_stop(handle);
  delete handle;
}

void vis_stub_set_pcm_callback(VisStubHandle* handle, void (*cb)(const PcmFrame&, void*),
                               void* ud) {
  if (!handle) return;
  handle->pcm_cb = cb;
  handle->pcm_ud = ud;
}

void vis_stub_set_spectrum_callback(VisStubHandle* handle, void (*cb)(const SpectrumFrame&, void*),
                                    void* ud) {
  if (!handle) return;
  handle->spectrum_cb = cb;
  handle->spectrum_ud = ud;
}

void vis_stub_start(VisStubHandle* handle) {
  if (!handle || handle->running.exchange(true)) return;
  handle->worker = std::thread(RunLoop, handle);
}

void vis_stub_stop(VisStubHandle* handle) {
  if (!handle) return;
  handle->running.store(false);
  if (handle->worker.joinable()) {
    handle->worker.join();
  }
}

}  // namespace sw
