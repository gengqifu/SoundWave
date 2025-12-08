#include <jni.h>
#include <cmath>
#include <vector>

#include "kissfft/kiss_fft.h"
#include "kissfft/kiss_fftr.h"

namespace {
std::vector<float> ComputeSpectrum(const float* samples, int len, int sample_rate, int window) {
  const int n = window;
  std::vector<float> hann(n);
  double energy = 0.0;
  for (int i = 0; i < n; ++i) {
    const double w = 0.5 * (1.0 - std::cos((2.0 * M_PI * i) / (n - 1)));
    hann[i] = static_cast<float>(w);
    energy += w * w;
  }
  energy /= static_cast<double>(n);

  std::vector<kiss_fft_scalar> in(n, 0.0f);
  const int copy = std::min(len, n);
  for (int i = 0; i < copy; ++i) {
    in[i] = samples[i] * hann[i];
  }

  kiss_fftr_cfg cfg = kiss_fftr_alloc(n, 0, nullptr, nullptr);
  if (!cfg) return {};
  std::vector<kiss_fft_cpx> out(n / 2 + 1);
  kiss_fftr(cfg, in.data(), out.data());
  free(cfg);

  std::vector<float> mags(n / 2);
  const double scale = energy > 0 ? (2.0 / (static_cast<double>(n) * energy)) : 0.0;
  for (int i = 0; i < n / 2; ++i) {
    const double re = out[i].r;
    const double im = out[i].i;
    mags[i] = static_cast<float>(std::hypot(re, im) * scale);
  }
  return mags;
}
}  // namespace

extern "C" JNIEXPORT jfloatArray JNICALL
Java_com_soundwave_player_NativeFft_computeFft(JNIEnv* env, jobject /*thiz*/,
                                               jfloatArray j_samples, jint sample_rate,
                                               jint window_size) {
  if (!j_samples || sample_rate <= 0 || window_size <= 0) {
    return nullptr;
  }
  jsize len = env->GetArrayLength(j_samples);
  std::vector<float> samples(len);
  env->GetFloatArrayRegion(j_samples, 0, len, samples.data());

  auto mags = ComputeSpectrum(samples.data(), static_cast<int>(samples.size()), sample_rate,
                              window_size);
  if (mags.empty()) {
    return nullptr;
  }
  jfloatArray out = env->NewFloatArray(static_cast<jsize>(mags.size()));
  env->SetFloatArrayRegion(out, 0, static_cast<jsize>(mags.size()), mags.data());
  return out;
}
