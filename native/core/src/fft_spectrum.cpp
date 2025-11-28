#include "fft_spectrum.h"

namespace sw {

std::vector<float> ComputeSpectrum(const std::vector<float>& samples, int sample_rate,
                                   const SpectrumConfig& cfg) {
  (void)samples;
  (void)sample_rate;
  (void)cfg;
  // TODO: 实现窗口化 + FFT + 谱功率计算。
  return {};
}

}  // namespace sw
