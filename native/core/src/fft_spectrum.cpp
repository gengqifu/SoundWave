#include "fft_spectrum.h"

#include <algorithm>
#include <cmath>
#include <vector>

#include "kiss_fftr.h"

namespace sw {
namespace {

constexpr float kPi = 3.14159265358979323846f;

inline float Hann(int n, int N) {
  return 0.5f * (1.0f - std::cos(2.0f * kPi * n / static_cast<float>(N - 1)));
}

inline float Hamming(int n, int N) {
  return 0.54f - 0.46f * std::cos(2.0f * kPi * n / static_cast<float>(N - 1));
}

}  // namespace

std::vector<float> DownmixToMono(const float* data, int num_frames, int num_channels,
                                 int window_size) {
  if (data == nullptr || num_frames <= 0 || num_channels <= 0) {
    return {};
  }
  const int window = window_size > 0 ? std::min(window_size, num_frames) : num_frames;
  if (window <= 0) return {};

  std::vector<float> mono(static_cast<size_t>(window), 0.0f);
  for (int i = 0; i < window; ++i) {
    const int base = i * num_channels;
    float sum = 0.0f;
    for (int c = 0; c < num_channels; ++c) {
      sum += data[static_cast<size_t>(base + c)];
    }
    mono[static_cast<size_t>(i)] = sum / static_cast<float>(num_channels);
  }
  return mono;
}

std::vector<float> ComputeSpectrum(const std::vector<float>& samples, int sample_rate,
                                   const SpectrumConfig& cfg) {
  (void)sample_rate;
  const int N = cfg.window_size;
  if (N <= 0 || static_cast<int>(samples.size()) < N) {
    return {};
  }

  std::vector<float> windowed(samples.begin(), samples.begin() + N);
  float window_sum = 0.0f;
  for (int i = 0; i < N; ++i) {
    float w = 1.0f;
    switch (cfg.window) {
      case WindowType::kHann:
        w = Hann(i, N);
        break;
      case WindowType::kHamming:
        w = Hamming(i, N);
        break;
      default:
        w = 1.0f;
        break;
    }
    windowed[static_cast<size_t>(i)] *= w;
    window_sum += w;
  }
  if (window_sum <= 0.0f) {
    return {};
  }
  const float inv_window_sum = 1.0f / window_sum;

  std::vector<float> spectrum(static_cast<size_t>(N / 2 + 1), 0.0f);
  kiss_fftr_cfg cfg_fft = kiss_fftr_alloc(N, 0, nullptr, nullptr);
  if (!cfg_fft) {
    return {};
  }
  std::vector<kiss_fft_cpx> freq(static_cast<size_t>(N / 2 + 1));
  kiss_fftr(cfg_fft, windowed.data(), freq.data());
  kiss_fftr_free(cfg_fft);

  for (size_t k = 0; k < spectrum.size(); ++k) {
    const float real = freq[k].r;
    const float imag = freq[k].i;
    const float mag2 = real * real + imag * imag;
    spectrum[k] =
        cfg.power_spectrum ? (mag2 * inv_window_sum * inv_window_sum)
                           : (std::sqrt(mag2) * inv_window_sum);
  }

  return spectrum;
}

}  // namespace sw
