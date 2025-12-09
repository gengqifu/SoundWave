package com.soundwave.visualization.core

/**
 * 原生回调接口：合成信号闭环验证用。
 */
interface NativeCallback {
    fun onPcm(data: FloatArray, frames: Int, channels: Int, timestampMs: Long)
    fun onSpectrum(bins: FloatArray, windowSize: Int, sampleRate: Int, timestampMs: Long)
}
