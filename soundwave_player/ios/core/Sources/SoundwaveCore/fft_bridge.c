#include "fft_bridge.h"

#include <stdlib.h>

#include "kiss_fftr.h"
#include "_kiss_fft_guts.h"

// 简单 Hann/Hamming 窗口。
static float window_value(int n, int N, int window_type) {
  switch (window_type) {
    case 1:  // Hamming
      return 0.54f - 0.46f * cosf(2.0f * (float)KISS_FFT_PI * n / (float)(N - 1));
    default:  // Hann
      return 0.5f * (1.0f - cosf(2.0f * (float)KISS_FFT_PI * n / (float)(N - 1)));
  }
}

int sw_fft_compute(const float* samples,
                   size_t length,
                   int sample_rate,
                   int window_size,
                   int window_type,
                   bool power_spectrum,
                   float** out_spectrum,
                   size_t* out_len,
                   float* out_bin_hz) {
  if (!samples || length == 0 || sample_rate <= 0 || window_size <= 0 ||
      !out_spectrum || !out_len || !out_bin_hz) {
    return -1;
  }
  if ((int)length < window_size) {
    return -2;
  }
  const int N = window_size;
  float* windowed = (float*)malloc(sizeof(float) * (size_t)N);
  if (!windowed) return -3;
  float window_sum = 0.0f;
  for (int n = 0; n < N; ++n) {
    const float w = window_value(n, N, window_type);
    windowed[n] = samples[n] * w;
    window_sum += w;
  }
  if (window_sum <= 0.0f) {
    free(windowed);
    return -4;
  }
  const float inv_window_sum = 1.0f / window_sum;

  kiss_fftr_cfg cfg = kiss_fftr_alloc(N, 0, NULL, NULL);
  if (!cfg) {
    free(windowed);
    return -5;
  }
  kiss_fft_cpx* freq = (kiss_fft_cpx*)malloc(sizeof(kiss_fft_cpx) * (size_t)(N / 2 + 1));
  if (!freq) {
    free(cfg);
    free(windowed);
    return -6;
  }

  kiss_fftr(cfg, windowed, freq);
  free(windowed);
  kiss_fftr_free(cfg);

  const size_t bins = (size_t)(N / 2 + 1);
  float* spectrum = (float*)malloc(sizeof(float) * bins);
  if (!spectrum) {
    free(freq);
    return -7;
  }
  for (size_t k = 0; k < bins; ++k) {
    const float real = freq[k].r;
    const float imag = freq[k].i;
    const float mag2 = real * real + imag * imag;
    spectrum[k] =
        power_spectrum ? (mag2 * inv_window_sum * inv_window_sum)
                       : (sqrtf(mag2) * inv_window_sum);
  }

  free(freq);
  *out_spectrum = spectrum;
  *out_len = bins;
  *out_bin_hz = (float)sample_rate / (float)N;
  return 0;
}

void sw_fft_free(float* ptr) {
  if (ptr) free(ptr);
}
