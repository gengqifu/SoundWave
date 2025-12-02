package com.soundwave.player

import android.content.Context
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink

@UnstableApi
class PcmRenderersFactory(
  context: Context,
  private val tapProcessor: PcmTapProcessor
) : DefaultRenderersFactory(context) {
  override fun buildAudioSink(
    context: Context,
    enableFloatOutput: Boolean,
    enableFloatOutput24Bit: Boolean,
    enableAudioTrackPlaybackParams: Boolean
  ): AudioSink {
    return DefaultAudioSink.Builder()
      .setAudioProcessors(arrayOf(tapProcessor))
      .setEnableFloatOutput(enableFloatOutput)
      .setEnableAudioTrackPlaybackParams(enableAudioTrackPlaybackParams)
      .build()
  }
}
