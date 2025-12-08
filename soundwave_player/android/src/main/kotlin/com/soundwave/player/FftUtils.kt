package com.soundwave.player

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sin

internal object FftUtils {
  data class Spectrum(val bins: FloatArray, val binHz: Double)

  /**
   * Compute magnitude spectrum with Hann window and amplitude normalization:
   * scale = 2 / (N * sum(w^2)/N). Bin 0/Nyquist are not halved for simplicity (visualization use).
   */
  fun computeSpectrum(
    samples: FloatArray,
    sampleRate: Int,
    windowSize: Int = 1024
  ): Spectrum? {
    if (samples.isEmpty() || sampleRate <= 0 || windowSize <= 0) return null
    val n = windowSize
    val hann = FloatArray(n) { i -> 0.5f * (1f - cos((2f * PI * i) / (n - 1))) }
    var energy = 0.0
    for (v in hann) energy += (v * v).toDouble()
    energy /= n

    val re = FloatArray(n)
    val im = FloatArray(n)
    val len = minOf(samples.size, n)
    for (i in 0 until len) {
      re[i] = samples[i] * hann[i]
    }
    // Cooley–Tukey radix-2 FFT (in-place).
    var j = 0
    for (i in 1 until n) {
      var bit = n shr 1
      while (j and bit != 0) {
        j = j xor bit
        bit = bit shr 1
      }
      j = j xor bit
      if (i < j) {
        val tr = re[i]; re[i] = re[j]; re[j] = tr
        val ti = im[i]; im[i] = im[j]; im[j] = ti
      }
    }
    var lenM = 2
    while (lenM <= n) {
      val angle = -2.0 * PI / lenM
      val wLenRe = cos(angle)
      val wLenIm = sin(angle)
      var k = 0
      while (k < n) {
        var wRe = 1.0
        var wIm = 0.0
        var m = 0
        while (m < lenM / 2) {
          val evenRe = re[k + m]
          val evenIm = im[k + m]
          val oddRe = re[k + m + lenM / 2]
          val oddIm = im[k + m + lenM / 2]
          val tRe = wRe * oddRe - wIm * oddIm
          val tIm = wRe * oddIm + wIm * oddRe
          re[k + m] = (evenRe + tRe).toFloat()
          im[k + m] = (evenIm + tIm).toFloat()
          re[k + m + lenM / 2] = (evenRe - tRe).toFloat()
          im[k + m + lenM / 2] = (evenIm - tIm).toFloat()
          val tmpRe = wRe
          wRe = tmpRe * wLenRe - wIm * wLenIm
          wIm = tmpRe * wLenIm + wIm * wLenRe
          m++
        }
        k += lenM
      }
      lenM = lenM shl 1
    }

    val scale = if (energy > 0) (2.0 / (n * energy)) else 0.0
    val half = n / 2
    val mags = FloatArray(half)
    for (i in 0 until half) {
      val mag = kotlin.math.hypot(re[i].toDouble(), im[i].toDouble()) * scale
      mags[i] = mag.toFloat()
    }
    val binHz = sampleRate.toDouble() / n
    return Spectrum(mags, binHz)
  }
}
