#include <jni.h>
#include <vector>

#include "fft_spectrum.h"

extern "C" JNIEXPORT jfloatArray JNICALL
Java_com_soundwave_core_SpectrumEngine_computeSpectrumNative(
    JNIEnv* env, jobject /*thiz*/, jfloatArray samples, jint sample_rate,
    jint window_size, jint window_type, jboolean power_spectrum) {
  if (samples == nullptr || sample_rate <= 0 || window_size <= 0) {
    return nullptr;
  }

  const jsize len = env->GetArrayLength(samples);
  if (len <= 0) return nullptr;
  std::vector<float> input(static_cast<size_t>(len));
  env->GetFloatArrayRegion(samples, 0, len, input.data());

  sw::SpectrumConfig cfg;
  cfg.window_size = window_size;
  cfg.power_spectrum = power_spectrum == JNI_TRUE;
  cfg.window = (window_type == 1) ? sw::WindowType::kHamming : sw::WindowType::kHann;

  const auto spectrum = sw::ComputeSpectrum(input, static_cast<int>(sample_rate), cfg);
  if (spectrum.empty()) {
    return nullptr;
  }

  jfloatArray out = env->NewFloatArray(static_cast<jsize>(spectrum.size()));
  if (out == nullptr) return nullptr;
  env->SetFloatArrayRegion(out, 0, static_cast<jsize>(spectrum.size()), spectrum.data());
  return out;
}
