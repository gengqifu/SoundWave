package com.soundwave.player

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.test.Test
import kotlin.test.assertTrue

internal class FftConsistencyTest {

  private fun naiveSpectrum(samples: FloatArray, sampleRate: Int, n: Int): Pair<FloatArray, Double> {
    val hann = FloatArray(n) { i -> 0.5f * (1f - cos((2f * PI * i) / (n - 1))) }
    var energy = 0.0
    hann.forEach { energy += (it * it).toDouble() }
    energy /= n

    val re = FloatArray(n)
    val im = FloatArray(n)
    val copy = minOf(samples.size, n)
    for (i in 0 until copy) {
      re[i] = samples[i] * hann[i]
    }
    // naive DFT
    val mags = FloatArray(n / 2)
    for (k in 0 until n / 2) {
      var r = 0.0
      var m = 0.0
      for (t in 0 until n) {
        val angle = -2.0 * PI * k * t / n
        val c = cos(angle)
        val s = sin(angle)
        r += re[t] * c - im[t] * s // im=0
        m += re[t] * s + im[t] * c
      }
      mags[k] = (hypot(r, m) * (if (energy > 0) 2.0 / (n * energy) else 0.0)).toFloat()
    }
    val binHz = sampleRate.toDouble() / n
    return mags to binHz
  }

  @Test
  fun hannNormalizedSpectrumMatchesNaiveDFT() {
    val sr = 44100
    val n = 1024
    val freq1 = 1000.0
    val freq2 = 5000.0
    val samples = FloatArray(n) { i ->
      (0.6 * sin(2.0 * PI * freq1 * i / sr) + 0.4 * sin(2.0 * PI * freq2 * i / sr)).toFloat()
    }

    val native = FftUtils.computeSpectrum(samples, sr, n)!!
    val naive = naiveSpectrum(samples, sr, n)

    // Compare a few key bins around expected peaks.
    val p1 = (freq1 * n / sr).roundToInt()
    val p2 = (freq2 * n / sr).roundToInt()
    val tol = 1e-3
    assertTrue(abs(native.bins[p1] - naive.first[p1]) < tol, "peak1 diff=${abs(native.bins[p1]-naive.first[p1])}")
    assertTrue(abs(native.bins[p2] - naive.first[p2]) < tol, "peak2 diff=${abs(native.bins[p2]-naive.first[p2])}")
    // Bin Hz should match definition.
    assertTrue(abs(native.binHz - naive.second) < 1e-9)
  }
}
