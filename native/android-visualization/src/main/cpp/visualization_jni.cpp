#include <jni.h>
#include <atomic>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "visualization_core_stub.h"

namespace {
JavaVM* g_vm = nullptr;
std::mutex g_mutex;
std::unique_ptr<sw::VisStubHandle> g_handle;
jobject g_callback = nullptr;
jmethodID g_on_pcm = nullptr;
jmethodID g_on_spectrum = nullptr;

JNIEnv* GetEnv() {
  JNIEnv* env = nullptr;
  if (g_vm && g_vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) == JNI_OK) {
    return env;
  }
  if (g_vm && g_vm->AttachCurrentThread(&env, nullptr) == JNI_OK) {
    return env;
  }
  return nullptr;
}

void PcmCb(const sw::PcmFrame& f, void* /*ud*/) {
  JNIEnv* env = GetEnv();
  if (!env || !g_callback || !g_on_pcm) return;
  const size_t count = static_cast<size_t>(f.num_frames * f.num_channels);
  jfloatArray arr = env->NewFloatArray(static_cast<jsize>(count));
  if (!arr) return;
  env->SetFloatArrayRegion(arr, 0, static_cast<jsize>(count), f.data);
  env->CallVoidMethod(g_callback, g_on_pcm, arr, f.num_frames, f.num_channels,
                      static_cast<jlong>(f.timestamp_ms));
  env->DeleteLocalRef(arr);
}

void SpectrumCb(const sw::SpectrumFrame& s, void* /*ud*/) {
  JNIEnv* env = GetEnv();
  if (!env || !g_callback || !g_on_spectrum) return;
  jfloatArray arr = env->NewFloatArray(static_cast<jsize>(s.num_bins));
  if (!arr) return;
  env->SetFloatArrayRegion(arr, 0, static_cast<jsize>(s.num_bins), s.bins);
  env->CallVoidMethod(g_callback, g_on_spectrum, arr, s.window_size, s.sample_rate,
                      static_cast<jlong>(s.timestamp_ms));
  env->DeleteLocalRef(arr);
}

void ClearHandle(JNIEnv* env) {
  if (g_handle) {
    sw::vis_stub_stop(g_handle.get());
    sw::vis_stub_destroy(g_handle.release());
  }
  if (g_callback) {
    env->DeleteGlobalRef(g_callback);
    g_callback = nullptr;
  }
  g_on_pcm = nullptr;
  g_on_spectrum = nullptr;
}
}  // namespace

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
  g_vm = vm;
  return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_soundwave_visualization_core_NativeBridge_nativeVersion(JNIEnv* env, jobject /*thiz*/) {
  return env->NewStringUTF("0.0.2-native-stub");
}

extern "C" JNIEXPORT void JNICALL
Java_com_soundwave_visualization_core_NativeBridge_nativeStartStub(JNIEnv* env, jclass,
                                                                   jobject callback,
                                                                   jint sampleRate, jint channels,
                                                                   jint framesPerBuffer,
                                                                   jint pcmMaxFps,
                                                                   jint spectrumMaxFps) {
  std::lock_guard<std::mutex> lock(g_mutex);
  ClearHandle(env);

  sw::VisStubConfig cfg;
  cfg.sample_rate = sampleRate > 0 ? sampleRate : 44100;
  cfg.channels = channels > 0 ? channels : 2;
  cfg.frames_per_buffer = framesPerBuffer > 0 ? framesPerBuffer : 256;
  cfg.pcm_max_fps = pcmMaxFps > 0 ? pcmMaxFps : 60;
  cfg.spectrum_max_fps = spectrumMaxFps > 0 ? spectrumMaxFps : 30;
  cfg.spectrum_cfg.window_size = cfg.frames_per_buffer;
  cfg.spectrum_cfg.window = sw::WindowType::kHann;
  cfg.spectrum_cfg.power_spectrum = false;  // 幅度谱，便于对齐。

  g_handle.reset(sw::vis_stub_create(cfg));
  if (!g_handle) return;

  jclass cls = env->GetObjectClass(callback);
  g_on_pcm = env->GetMethodID(cls, "onPcm", "([FIIJ)V");
  g_on_spectrum = env->GetMethodID(cls, "onSpectrum", "([FIIJ)V");
  g_callback = env->NewGlobalRef(callback);

  sw::vis_stub_set_pcm_callback(g_handle.get(), PcmCb, nullptr);
  sw::vis_stub_set_spectrum_callback(g_handle.get(), SpectrumCb, nullptr);
  sw::vis_stub_start(g_handle.get());
}

extern "C" JNIEXPORT void JNICALL
Java_com_soundwave_visualization_core_NativeBridge_nativeStopStub(JNIEnv* env, jclass) {
  std::lock_guard<std::mutex> lock(g_mutex);
  ClearHandle(env);
}
