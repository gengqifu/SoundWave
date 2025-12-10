#include "pcm_event_bus.h"

#include <gtest/gtest.h>
#include <vector>

namespace sw {

struct CapturedSpectrum {
  SpectrumFrame frame;
  std::vector<float> bins;
};

TEST(PcmEventBusTest, EmitsDownmixedNormalizedSpectrum) {
  PcmIngressConfig ingress_cfg;
  ingress_cfg.expected_sample_rate = 48000;
  ingress_cfg.expected_channels = 2;
  ingress_cfg.throttle.max_fps = 100;
  ingress_cfg.throttle.max_pending = 4;

  SpectrumConfig spectrum_cfg;
  spectrum_cfg.window_size = 4;
  spectrum_cfg.window = WindowType::kHann;
  spectrum_cfg.power_spectrum = false;

  PcmEventBus bus(ingress_cfg, spectrum_cfg);

  std::vector<PcmFrame> pcm_events;
  std::vector<CapturedSpectrum> spec_events;
  bus.SetPcmCallback([&](const PcmFrame& f) { pcm_events.push_back(f); });
  bus.SetSpectrumCallback([&](const SpectrumFrame& f) {
    CapturedSpectrum s;
    s.frame = f;
    s.bins.assign(f.bins, f.bins + f.num_bins);
    spec_events.push_back(std::move(s));
  });

  // Stereo → downmix to mono (0.5f constant); expect DC bin normalized to ~0.5。
  std::vector<float> samples = {
      1.0f, 0.0f,  // frame 0 (L, R)
      1.0f, 0.0f,  // frame 1
      1.0f, 0.0f,  // frame 2
      1.0f, 0.0f   // frame 3
  };
  PcmInputFrame frame{samples.data(), 4, 48000, 2, 10, 1};

  EXPECT_EQ(bus.Push(frame, /*now_ms=*/0), Status::kOk);
  ASSERT_EQ(pcm_events.size(), 1u);
  EXPECT_EQ(pcm_events[0].sequence, 1u);
  EXPECT_EQ(pcm_events[0].timestamp_ms, 10);
  EXPECT_EQ(pcm_events[0].num_frames, 2);
  EXPECT_EQ(pcm_events[0].num_channels, 2);
  ASSERT_TRUE(pcm_events[0].owner);
  EXPECT_EQ(pcm_events[0].owner->size(), samples.size());

  ASSERT_EQ(spec_events.size(), 1u);
  EXPECT_EQ(spec_events[0].frame.num_bins, spectrum_cfg.window_size / 2 + 1);
  EXPECT_EQ(spec_events[0].frame.sample_rate, 48000);
  EXPECT_EQ(spec_events[0].frame.window_size, spectrum_cfg.window_size);
  EXPECT_NEAR(spec_events[0].frame.bin_hz,
              static_cast<float>(frame.sample_rate) / spectrum_cfg.window_size, 1e-6f);
  ASSERT_EQ(spec_events[0].bins.size(), static_cast<size_t>(spectrum_cfg.window_size / 2 + 1));
  EXPECT_NEAR(spec_events[0].bins[0], 0.5f, 1e-3f);
  for (size_t i = 1; i < spec_events[0].bins.size(); ++i) {
    EXPECT_NEAR(spec_events[0].bins[i], 0.0f, 1e-4f);
  }
}

}  // namespace sw
