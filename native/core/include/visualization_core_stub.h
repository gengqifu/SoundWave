#pragma once

#include <cstdint>

#include "audio_engine.h"
#include "fft_spectrum.h"
#include "pcm_throttler.h"

namespace sw {

struct VisStubConfig {
  int sample_rate = 44100;
  int channels = 2;
  int frames_per_buffer = 256;
  int pcm_max_fps = 60;
  int spectrum_max_fps = 30;
  SpectrumConfig spectrum_cfg;
};

struct VisStubHandle;

VisStubHandle* vis_stub_create(const VisStubConfig& cfg);
void vis_stub_destroy(VisStubHandle* handle);

void vis_stub_set_pcm_callback(VisStubHandle* handle, void (*cb)(const PcmFrame&, void*),
                               void* ud);
void vis_stub_set_spectrum_callback(VisStubHandle* handle, void (*cb)(const SpectrumFrame&, void*),
                                    void* ud);

// 启动/停止合成信号（正弦）推流，供原生闭环验证。
void vis_stub_start(VisStubHandle* handle);
void vis_stub_stop(VisStubHandle* handle);

}  // namespace sw
