package com.soundwave.player

import kotlin.math.abs
import kotlin.math.PI
import kotlin.math.sin
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

internal class FftUtilsTest {

  @Test
  fun singleTonePeaksAtExpectedBin() {
    val sr = 44100
    val n = 1024
    val freq = 1000.0
    val samples = FloatArray(n) { i -> sin(2.0 * PI * freq * i / sr).toFloat() }

    val spec = FftUtils.computeSpectrum(samples, sr, n)!!

    val expectedBin = (freq * n / sr).roundToInt()
    val peakIndex = spec.bins.indices.maxByOrNull { spec.bins[it] } ?: -1
    assertTrue(abs(peakIndex - expectedBin) <= 1, "peak bin=$peakIndex expected≈$expectedBin")
    assertTrue(spec.bins[peakIndex] > 0.8f, "peak magnitude should be ~1, got ${spec.bins[peakIndex]}")
  }

  @Test
  fun dualToneShowsTwoPeaks() {
    val sr = 44100
    val n = 1024
    val f1 = 1000.0
    val f2 = 5000.0
    val samples = FloatArray(n) { i ->
      (0.5 * sin(2.0 * PI * f1 * i / sr) + 0.5 * sin(2.0 * PI * f2 * i / sr)).toFloat()
    }

    val spec = FftUtils.computeSpectrum(samples, sr, n)!!
    val sorted = spec.bins
      .mapIndexed { idx, v -> idx to v }
      .sortedByDescending { it.second }
      .take(2)
      .map { it.first }

    val expected1 = (f1 * n / sr).roundToInt()
    val expected2 = (f2 * n / sr).roundToInt()
    assertTrue(sorted.any { abs(it - expected1) <= 1 }, "missing peak near $expected1")
    assertTrue(sorted.any { abs(it - expected2) <= 1 }, "missing peak near $expected2")
    assertTrue(spec.bins[sorted[0]] > 0.3f && spec.bins[sorted[1]] > 0.3f)
  }
}
