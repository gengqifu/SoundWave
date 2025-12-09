package com.soundwave.visualization.core

/**
 * 占位 API：后续将挂接 JNI 到 native/core (PCM/FFT/导出)。
 */
object VisualizationCore {
    const val VERSION = "0.0.2-native-SNAPSHOT"

    /**
     * 当前仅返回 native 占位版本号，验证 JNI/NDK 依赖链。
     */
    @JvmStatic
    fun nativeVersion(): String = NativeBridge.nativeVersion()

    /**
     * 启动合成信号闭环（仅验证）：生成正弦 -> 节流 -> PCM/谱回调。
     */
    @JvmStatic
    fun startStub(callback: NativeCallback,
                  sampleRate: Int = 44100,
                  channels: Int = 2,
                  framesPerBuffer: Int = 256,
                  pcmMaxFps: Int = 60,
                  spectrumMaxFps: Int = 30) {
        NativeBridge.nativeStartStub(callback, sampleRate, channels, framesPerBuffer, pcmMaxFps, spectrumMaxFps)
    }

    @JvmStatic
    fun stopStub() = NativeBridge.nativeStopStub()
}
