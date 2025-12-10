package com.soundwave.host

import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import com.google.android.material.button.MaterialButton
import com.soundwave.adapter.PcmRenderersFactory
import com.soundwave.adapter.PcmTapProcessor
import com.soundwave.core.SpectrumEngine

class MainActivity : AppCompatActivity() {

  private val tap = PcmTapProcessor()
  private val spectrum = SpectrumEngine(windowSize = 1024)
  private lateinit var player: ExoPlayer
  private val handler = Handler(Looper.getMainLooper())
  private val sampleRateGuess = 48000 // Adapter未包含采样率，这里使用常见的 48k 作为估计。

  private val pollTask = object : Runnable {
    override fun run() {
      val frames = tap.drain(4)
      val dropped = tap.droppedSinceLastDrain()
      val sb = StringBuilder()
      if (dropped > 0) sb.append("dropped=").append(dropped).append("\n")
      frames.forEach { frame ->
        val spec = spectrum.compute(frame.samples, sampleRateGuess)
        spec?.let {
          // 取前三个频点粗略展示
          val top = it.take(3).joinToString(prefix = "[", postfix = "]") { v -> "%.4f".format(v) }
          sb.append("seq=").append(frame.sequence)
            .append(" bins=").append(it.size)
            .append(" top3=").append(top)
            .append("\n")
        }
      }
      if (sb.isNotEmpty()) {
        findViewById<android.widget.TextView>(R.id.logView).text = sb.toString()
        Log.d("HostSpectrum", sb.toString())
      }
      handler.postDelayed(this, 500)
    }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_main)

    player = ExoPlayer.Builder(this, PcmRenderersFactory(this, tap)).build()

    findViewById<MaterialButton>(R.id.playButton).setOnClickListener {
      // 默认示例为一个公开 mp3 链接，若离线请替换为本地文件 Uri。
      val mediaItem = MediaItem.fromUri(
        Uri.parse("https://samplelib.com/lib/preview/mp3/sample-3s.mp3")
      )
      player.setMediaItem(mediaItem)
      player.prepare()
      player.play()
      handler.post(pollTask)
      findViewById<android.widget.TextView>(R.id.status).text = "Playing sample…"
    }

    findViewById<MaterialButton>(R.id.stopButton).setOnClickListener {
      player.pause()
      handler.removeCallbacks(pollTask)
      findViewById<android.widget.TextView>(R.id.status).text = "Stopped"
    }
  }

  override fun onDestroy() {
    super.onDestroy()
    handler.removeCallbacks(pollTask)
    player.release()
  }
}
