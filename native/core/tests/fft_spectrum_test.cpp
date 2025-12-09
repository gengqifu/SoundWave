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

TEST(FftSpectrumTest, DifferentWindowSizesProduceExpectedBins) {
  const int sample_rate = 48000;
  SpectrumConfig cfg;
  cfg.window = WindowType::kHamming;

  cfg.window_size = 256;
  std::vector<float> samples_small(cfg.window_size);
  auto spec_small = ComputeSpectrum(samples_small, sample_rate, cfg);
  ASSERT_EQ(static_cast<int>(spec_small.size()), cfg.window_size / 2 + 1);
  const float bin_hz_small = static_cast<float>(sample_rate) / cfg.window_size;
  EXPECT_NEAR(bin_hz_small, 187.5f, 1e-3f);

  cfg.window_size = 1024;
  std::vector<float> samples_large(cfg.window_size);
  auto spec_large = ComputeSpectrum(samples_large, sample_rate, cfg);
  ASSERT_EQ(static_cast<int>(spec_large.size()), cfg.window_size / 2 + 1);
  const float bin_hz_large = static_cast<float>(sample_rate) / cfg.window_size;
  EXPECT_NEAR(bin_hz_large, 46.875f, 1e-3f);

  // Invalid window larger than input should return empty.
  cfg.window_size = 2048;
  auto spec_empty = ComputeSpectrum(samples_small, sample_rate, cfg);
  EXPECT_TRUE(spec_empty.empty());
}

TEST(FftSpectrumTest, TwoToneHasTwoDominantPeaks) {
  const int sample_rate = 48000;
  const int window = 2048;
  const float f1 = 1000.0f;
  const float f2 = 5000.0f;
  std::vector<float> samples(window);
  for (int n = 0; n < window; ++n) {
    const float t = static_cast<float>(n) / sample_rate;
    samples[n] = std::sin(2.0f * static_cast<float>(M_PI) * f1 * t) +
                 0.7f * std::sin(2.0f * static_cast<float>(M_PI) * f2 * t);
  }

  SpectrumConfig cfg;
  cfg.window_size = window;
  cfg.window = WindowType::kHann;
  cfg.power_spectrum = true;

  auto spectrum = ComputeSpectrum(samples, sample_rate, cfg);
  ASSERT_EQ(static_cast<int>(spectrum.size()), window / 2 + 1);

  // 找到两个最大峰值 bin。
  struct BinVal {
    int bin;
    float val;
  };
  std::vector<BinVal> bins;
  bins.reserve(spectrum.size());
  for (int i = 0; i < static_cast<int>(spectrum.size()); ++i) {
    bins.push_back({i, spectrum[i]});
  }
  std::partial_sort(bins.begin(), bins.begin() + 5, bins.end(),
                    [](const BinVal& a, const BinVal& b) { return a.val > b.val; });
  const auto top5 = std::vector<BinVal>(bins.begin(), bins.begin() + 5);

  const int expected_bin1 = static_cast<int>(std::round(f1 * window / sample_rate));
  const int expected_bin2 = static_cast<int>(std::round(f2 * window / sample_rate));
  auto close_to = [](int bin, int expected) { return std::abs(bin - expected) <= 2; };
  bool has_f1 = false;
  bool has_f2 = false;
  for (const auto& bv : top5) {
    if (close_to(bv.bin, expected_bin1)) has_f1 = true;
    if (close_to(bv.bin, expected_bin2)) has_f2 = true;
  }
  EXPECT_TRUE(has_f1);
  EXPECT_TRUE(has_f2);
  EXPECT_GT(top5.front().val, 0.05f);
}

TEST(FftSpectrumTest, WhiteNoiseHasBroadEnergy) {
  const int sample_rate = 48000;
  const int window = 1024;
  std::vector<float> samples(window);
  // 简单确定性噪声生成（无需随机种子）。
  float val = 0.1234f;
  for (int n = 0; n < window; ++n) {
    val = std::fmod(val * 3.987f + 0.015f, 1.0f);
    samples[n] = val * 2.0f - 1.0f;
  }

  SpectrumConfig cfg;
  cfg.window_size = window;
  cfg.window = WindowType::kHamming;
  cfg.power_spectrum = true;

  auto spectrum = ComputeSpectrum(samples, sample_rate, cfg);
  ASSERT_EQ(static_cast<int>(spectrum.size()), window / 2 + 1);

  // 能量应分布较均匀：均值大于 0，标准差不为 0。
  double sum = 0.0;
  for (float v : spectrum) {
    sum += v;
  }
  const double mean = sum / spectrum.size();
  EXPECT_GT(mean, 0.0);

  double var = 0.0;
  for (float v : spectrum) {
    const double d = v - mean;
    var += d * d;
  }
  var /= spectrum.size();
  EXPECT_GT(var, 0.0);
}

}  // namespace sw
