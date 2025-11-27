#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace sw {

enum class WindowType { kHann, kHamming };

struct SpectrumConfig {
  int window_size = 1024;
  int overlap = 0;              // samples overlap between frames.
  WindowType window = WindowType::kHann;
  bool power_spectrum = true;   // true: power spectrum, false: magnitude.
};

// Compute single-frame spectrum from time-domain samples.
// Returns size window_size/2 + 1 bins (DC..Nyquist).
std::vector<float> ComputeSpectrum(const std::vector<float>& samples, int sample_rate,
                                   const SpectrumConfig& cfg);

}  // namespace sw
