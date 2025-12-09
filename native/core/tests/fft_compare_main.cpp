#include "fft_spectrum.h"

#include <cmath>
#include <fstream>
#include <iostream>
#include <random>
#include <sstream>
#include <string>
#include <vector>

namespace {

std::string ReadFile(const std::string& path) {
  std::ifstream f(path);
  std::stringstream ss;
  ss << f.rdbuf();
  return ss.str();
}

// 简单提取 JSON 中 key 的字符串值（如 "signal": "single"）。
std::string ExtractString(const std::string& json, const std::string& key) {
  const auto pos = json.find("\"" + key + "\"");
  if (pos == std::string::npos) return {};
  const auto colon = json.find(":", pos);
  const auto quote1 = json.find("\"", colon);
  const auto quote2 = json.find("\"", quote1 + 1);
  if (quote1 == std::string::npos || quote2 == std::string::npos) return {};
  return json.substr(quote1 + 1, quote2 - quote1 - 1);
}

// 提取数字类型的值（int/float）。
double ExtractNumber(const std::string& json, const std::string& key) {
  const auto pos = json.find("\"" + key + "\"");
  if (pos == std::string::npos) return 0.0;
  const auto colon = json.find(":", pos);
  std::stringstream ss(json.substr(colon + 1));
  double v = 0.0;
  ss >> v;
  return v;
}

// 提取 spectrum 数组。
std::vector<float> ExtractSpectrum(const std::string& json) {
  const auto key_pos = json.find("\"spectrum\"");
  if (key_pos == std::string::npos) return {};
  const auto lb = json.find("[", key_pos);
  const auto rb = json.find("]", lb);
  if (lb == std::string::npos || rb == std::string::npos) return {};
  std::string arr = json.substr(lb + 1, rb - lb - 1);
  std::stringstream ss(arr);
  std::vector<float> out;
  std::string token;
  while (std::getline(ss, token, ',')) {
    std::stringstream ts(token);
    float v;
    if (ts >> v) {
      out.push_back(v);
    }
  }
  return out;
}

float Hann(int n, int N) { return 0.5f * (1.0f - std::cos(2.0f * M_PI * n / float(N - 1))); }

float WindowEnergy(int N) {
  float e = 0.0f;
  for (int i = 0; i < N; ++i) e += Hann(i, N) * Hann(i, N);
  return e;
}

std::vector<float> GenerateSignal(const std::string& kind, int N, float fs) {
  std::vector<float> sig(N, 0.0f);
  if (kind == "single") {
    const float f = 1000.0f;
    for (int i = 0; i < N; ++i) sig[i] = std::sin(2.f * float(M_PI) * f * (i / fs));
  } else if (kind == "double") {
    const float f1 = 440.0f, f2 = 880.0f;
    for (int i = 0; i < N; ++i) {
      float t = i / fs;
      sig[i] = std::sin(2.f * float(M_PI) * f1 * t) + std::sin(2.f * float(M_PI) * f2 * t);
    }
  } else if (kind == "white") {
    std::mt19937 rng(42);
    std::uniform_real_distribution<float> dist(-1.0f, 1.0f);
    for (int i = 0; i < N; ++i) sig[i] = dist(rng);
  } else if (kind == "sweep") {
    const float f0 = 20.0f, f1 = 18000.0f;
    const float ratio = f1 / f0;
    for (int i = 0; i < N; ++i) {
      float t = i / fs;
      float f = f0 * std::pow(ratio, t * fs / N);
      sig[i] = std::sin(2.f * float(M_PI) * f * t);
    }
  }
  return sig;
}

struct Metrics {
  float l2{0};
  float max{0};
  int peak_bin{0};
  float peak_mag{0};
};

Metrics Compare(const std::vector<float>& ref, const std::vector<float>& got) {
  Metrics m;
  const size_t n = std::min(ref.size(), got.size());
  double l2 = 0.0;
  double maxerr = 0.0;
  for (size_t i = 0; i < n; ++i) {
    double diff = std::abs(ref[i] - got[i]);
    l2 += diff * diff;
    if (diff > maxerr) maxerr = diff;
  }
  m.l2 = static_cast<float>(std::sqrt(l2));
  m.max = static_cast<float>(maxerr);
  float peak = 0.0f;
  for (size_t i = 0; i < got.size(); ++i) {
    if (got[i] > peak) {
      peak = got[i];
      m.peak_bin = static_cast<int>(i);
      m.peak_mag = got[i];
    }
  }
  return m;
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 2) {
    std::cerr << "Usage: fft_compare <reference_json>" << std::endl;
    return 1;
  }
  const std::string json_text = ReadFile(argv[1]);
  if (json_text.empty()) {
    std::cerr << "Failed to read file: " << argv[1] << std::endl;
    return 1;
  }
  const std::string signal = ExtractString(json_text, "signal");
  const int nfft = static_cast<int>(ExtractNumber(json_text, "nfft"));
  const float fs = static_cast<float>(ExtractNumber(json_text, "fs"));
  const auto ref_spectrum = ExtractSpectrum(json_text);
  if (signal.empty()) std::cerr << "Missing field: signal" << std::endl;
  if (nfft <= 0) std::cerr << "Missing/invalid field: nfft" << std::endl;
  if (fs <= 0.0f) std::cerr << "Missing/invalid field: fs" << std::endl;
  if (ref_spectrum.empty()) std::cerr << "Missing field: spectrum" << std::endl;
  if (signal.empty() || nfft <= 0 || fs <= 0.0f || ref_spectrum.empty()) return 1;

  // 生成信号并计算谱（与参考同参数）
  auto samples = GenerateSignal(signal, nfft, fs);
  sw::SpectrumConfig cfg;
  cfg.window_size = nfft;
  cfg.window = sw::WindowType::kHann;
  cfg.power_spectrum = false;  // 需要幅度谱
  const auto raw_spectrum = sw::ComputeSpectrum(samples, static_cast<int>(fs), cfg);

  // 归一化 2/(N*E_window) 以匹配参考
  std::vector<float> norm_spectrum(raw_spectrum);
  float e_win = WindowEnergy(nfft);
  float norm = 2.0f / (nfft * e_win);
  for (auto& v : norm_spectrum) v *= norm;

  auto metrics = Compare(ref_spectrum, norm_spectrum);
  std::cout << "Signal: " << signal << "\n";
  std::cout << "NFFT: " << nfft << " fs: " << fs << "\n";
  std::cout << "Peak bin/mag (got): " << metrics.peak_bin << " / " << metrics.peak_mag << "\n";
  std::cout << "L2 error: " << metrics.l2 << " Max error: " << metrics.max << "\n";

  const float kThreshold = 1e-3f;
  if (metrics.l2 > kThreshold || metrics.max > kThreshold) {
    std::cerr << "ERROR: exceeds threshold " << kThreshold << std::endl;
    return 2;
  }
  std::cout << "OK: within threshold " << kThreshold << std::endl;
  return 0;
}
