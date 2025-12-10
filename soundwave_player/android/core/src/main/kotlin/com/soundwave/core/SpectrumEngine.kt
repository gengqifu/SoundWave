package com.soundwave.core

/**
 * 光谱计算引擎，调用原生 KissFFT。
 */
class SpectrumEngine(
  val windowSize: Int = 1024,
  val windowType: WindowType = WindowType.HANN,
  val powerSpectrum: Boolean = true
) {
  init {
    System.loadLibrary("soundwave_fft")
  }

  fun compute(samples: FloatArray, sampleRate: Int): FloatArray? {
    if (samples.isEmpty() || sampleRate <= 0) return null
    return computeSpectrumNative(samples, sampleRate, windowSize, windowType.ordinal, powerSpectrum)
  }

  private external fun computeSpectrumNative(
    samples: FloatArray,
    sampleRate: Int,
    windowSize: Int,
    windowType: Int,
    powerSpectrum: Boolean
  ): FloatArray?

  enum class WindowType { HANN, HAMMING }
}
