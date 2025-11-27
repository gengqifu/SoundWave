#include "fft_spectrum.h"

#include <gtest/gtest.h>

#include <cmath>
#include <vector>

namespace sw {

TEST(FftSpectrumTest, SingleToneHasPeakAtExpectedBin) {
  const int sample_rate = 48000;
  const int window = 1024;
  const float freq = 1000.0f;
  std::vector<float> samples(window);
  for (int n = 0; n < window; ++n) {
    samples[n] = std::sin(2.0f * static_cast<float>(M_PI) * freq * n / sample_rate);
  }

  SpectrumConfig cfg;
  cfg.window_size = window;
  cfg.window = WindowType::kHann;
  cfg.power_spectrum = true;

  auto spectrum = ComputeSpectrum(samples, sample_rate, cfg);
  ASSERT_EQ(static_cast<int>(spectrum.size()), window / 2 + 1);

  // 理论峰值所在 bin ≈ freq * window / sample_rate.
  const int expected_bin = static_cast<int>(std::round(freq * window / sample_rate));
  float peak = 0.0f;
  int peak_bin = 0;
  for (int i = 0; i < static_cast<int>(spectrum.size()); ++i) {
    if (spectrum[i] > peak) {
      peak = spectrum[i];
      peak_bin = i;
    }
  }
  EXPECT_EQ(peak_bin, expected_bin);
  EXPECT_GT(peak, 0.1f);
}

TEST(FftSpectrumTest, WindowAndOverlapConfigAffectsOutputSize) {
  const int sample_rate = 44100;
  SpectrumConfig cfg;
  cfg.window_size = 512;
  cfg.overlap = 256;
  cfg.window = WindowType::kHamming;
  std::vector<float> samples(cfg.window_size);
  auto spectrum = ComputeSpectrum(samples, sample_rate, cfg);
  EXPECT_EQ(static_cast<int>(spectrum.size()), cfg.window_size / 2 + 1);
}

}  // namespace sw
