#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// window_type: 0 = Hann, 1 = Hamming
// power_spectrum: true 返回功率谱，false 返回幅度谱
// 返回 0 成功，其余失败；调用方负责 free(out_spectrum)
int sw_fft_compute(const float* samples,
                   size_t length,
                   int sample_rate,
                   int window_size,
                   int window_type,
                   bool power_spectrum,
                   float** out_spectrum,
                   size_t* out_len,
                   float* out_bin_hz);

void sw_fft_free(float* ptr);

#ifdef __cplusplus
}
#endif
