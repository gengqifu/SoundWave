#include "pcm_event_bus.h"

#include <gtest/gtest.h>
#include <vector>

namespace sw {

TEST(PcmEventBusTest, EmitsPcmAndPlaceholderSpectrum) {
  PcmIngressConfig ingress_cfg;
  ingress_cfg.expected_sample_rate = 48000;
  ingress_cfg.expected_channels = 2;
  ingress_cfg.throttle.max_fps = 100;
  ingress_cfg.throttle.max_pending = 4;

  SpectrumConfig spectrum_cfg;
  spectrum_cfg.window_size = 4;
  spectrum_cfg.window = WindowType::kHann;
  spectrum_cfg.power_spectrum = true;

  PcmEventBus bus(ingress_cfg, spectrum_cfg);

  std::vector<PcmFrame> pcm_events;
  std::vector<SpectrumFrame> spec_events;
  bus.SetPcmCallback([&](const PcmFrame& f) { pcm_events.push_back(f); });
  bus.SetSpectrumCallback([&](const SpectrumFrame& f) { spec_events.push_back(f); });

  std::vector<float> samples = {0.1f, -0.1f, 0.2f, -0.2f};
  PcmInputFrame frame{samples.data(), 2, 48000, 2, 10, 1};

  EXPECT_EQ(bus.Push(frame, /*now_ms=*/0), Status::kOk);
  ASSERT_EQ(pcm_events.size(), 1u);
  EXPECT_EQ(pcm_events[0].sequence, 1u);
  EXPECT_EQ(pcm_events[0].timestamp_ms, 10);
  EXPECT_EQ(pcm_events[0].num_frames, 2);
  EXPECT_EQ(pcm_events[0].num_channels, 2);
  ASSERT_TRUE(pcm_events[0].owner);
  EXPECT_EQ(pcm_events[0].owner->size(), samples.size());

  ASSERT_EQ(spec_events.size(), 1u);
  EXPECT_EQ(spec_events[0].num_bins, spectrum_cfg.window_size / 2 + 1);
  EXPECT_EQ(spec_events[0].sample_rate, 48000);
  EXPECT_EQ(spec_events[0].window_size, spectrum_cfg.window_size);
}

}  // namespace sw
