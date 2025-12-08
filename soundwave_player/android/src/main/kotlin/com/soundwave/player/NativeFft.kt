package com.soundwave.player

internal object NativeFft {
  private var loaded = false
  init {
    try {
      System.loadLibrary("soundwave_fft")
      loaded = true
    } catch (_: UnsatisfiedLinkError) {
      loaded = false
    }
  }

  private external fun computeFft(samples: FloatArray, sampleRate: Int, windowSize: Int): FloatArray?

  fun compute(samples: FloatArray, sampleRate: Int, windowSize: Int = 1024): Pair<FloatArray, Double>? {
    if (!loaded) return FftUtils.computeSpectrum(samples, sampleRate, windowSize)
    val bins = computeFft(samples, sampleRate, windowSize) ?: return FftUtils.computeSpectrum(samples, sampleRate, windowSize)
    val binHz = sampleRate.toDouble() / windowSize
    return bins to binHz
  }
}
