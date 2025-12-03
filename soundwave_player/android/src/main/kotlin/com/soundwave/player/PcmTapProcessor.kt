package com.soundwave.player

import android.os.SystemClock
import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.exoplayer.audio.BaseAudioProcessor
import androidx.media3.common.util.UnstableApi
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicInteger

@UnstableApi
class PcmTapProcessor : BaseAudioProcessor() {
  private val queue: ConcurrentLinkedQueue<PcmFrame> = ConcurrentLinkedQueue()
  private var sequence: Long = 0
  private val droppedCounter = AtomicInteger(0)
  private val maxQueueFrames = 60
  private var channelCount: Int = 1

  override fun onConfigure(inputAudioFormat: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
    channelCount = if (inputAudioFormat.channelCount > 0) inputAudioFormat.channelCount else 1
    return inputAudioFormat
  }

  override fun queueInput(inputBuffer: ByteBuffer) {
    if (!inputBuffer.hasRemaining()) {
      return
    }

    // Copy input to output so playback continues.
    val outBuffer = replaceOutputBuffer(inputBuffer.remaining())
    val bufferForTap = inputBuffer.duplicate().order(ByteOrder.nativeOrder())
    outBuffer.put(inputBuffer)
    outBuffer.flip()
    
    val remaining = bufferForTap.remaining()
    val data = ByteArray(remaining)
    bufferForTap.get(data)

    val samples = when (outputAudioFormat.encoding) {
      C.ENCODING_PCM_16BIT -> {
        val bb = ByteBuffer.wrap(data).order(ByteOrder.nativeOrder())
        val arr = FloatArray(data.size / 2)
        var i = 0
        while (bb.hasRemaining()) {
          arr[i++] = bb.short.toFloat() / Short.MAX_VALUE
        }
        arr
      }
      C.ENCODING_PCM_FLOAT -> {
        val bb = ByteBuffer.wrap(data).order(ByteOrder.nativeOrder())
        val arr = FloatArray(data.size / 4)
        var i = 0
        while (bb.hasRemaining()) {
          arr[i++] = bb.float
        }
        arr
      }
      else -> FloatArray(0)
    }

    // Downmix multi-channel PCM to mono to avoid interleaved L/R introducing artificial high-frequency
    // energy in FFT and to keep waveform consistent across channels.
    val mono = if (channelCount <= 1 || samples.isEmpty()) {
      samples
    } else {
      val frames = samples.size / channelCount
      val mixed = FloatArray(frames)
      for (i in 0 until frames) {
        var sum = 0f
        for (ch in 0 until channelCount) {
          val idx = i * channelCount + ch
          if (idx < samples.size) sum += samples[idx]
        }
        mixed[i] = sum / channelCount
      }
      mixed
    }

    if (queue.size >= maxQueueFrames) {
      // Drop the oldest frame when over capacity.
      queue.poll()
      droppedCounter.incrementAndGet()
    }
    queue.add(PcmFrame(sequence++, SystemClock.elapsedRealtime(), mono))
  }

  override fun onQueueEndOfStream() {
    // No-op for tap
  }
  
  public override fun onReset() {
    queue.clear()
    sequence = 0
    droppedCounter.set(0)
  }

  fun drain(maxFrames: Int): List<PcmFrame> {
    if (maxFrames <= 0) return emptyList()
    val out = mutableListOf<PcmFrame>()
    repeat(maxFrames) {
      val f = queue.poll() ?: return@repeat
      out.add(f)
    }
    return out
  }

  fun droppedSinceLastDrain(): Int = droppedCounter.getAndSet(0)
}
