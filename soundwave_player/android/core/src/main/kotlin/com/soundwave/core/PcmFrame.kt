package com.soundwave.core

data class PcmFrame(
    val sequence: Long,
    val timestampMs: Long,
    val samples: FloatArray
)
