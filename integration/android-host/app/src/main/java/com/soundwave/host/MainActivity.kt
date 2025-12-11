package com.soundwave.host

import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.SeekBar
import android.widget.Spinner
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import com.google.android.material.button.MaterialButton
import com.soundwave.adapter.PcmRenderersFactory
import com.soundwave.adapter.PcmTapProcessor
import com.soundwave.core.SpectrumEngine

/**
 * Demo 主界面：选择资产音频，播放/暂停/停止/seek，并实时绘制波形+频谱。
 */
class MainActivity : AppCompatActivity() {

  private val tap = PcmTapProcessor()
  private val spectrum = SpectrumEngine(windowSize = 1024)
  private lateinit var player: ExoPlayer
  private val handler = Handler(Looper.getMainLooper())
  private val sampleRateGuess = 48000 // Adapter 未包含采样率，这里使用常见的 48k 作为估计。
  private lateinit var assetSpinner: Spinner
  private lateinit var waveformView: WaveformView
  private lateinit var spectrumView: SpectrumView
  private lateinit var seekBar: SeekBar
  private lateinit var timeLabel: TextView
  private lateinit var statusView: TextView
  private val supportExt = setOf(".wav", ".mp3")
  private var isScrubbing = false

  private val pollTask = object : Runnable {
    override fun run() {
      // 波形/频谱数据
      val frames = tap.drain(4)
      frames.forEach { frame ->
        waveformView.appendSamples(frame.samples)
        val spec = spectrum.compute(frame.samples, sampleRateGuess)
        spec?.let { spectrumView.setSpectrum(it) }
      }

      // 播放进度
      updateProgress()
      handler.postDelayed(this, 80)
    }
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_main)

    player = ExoPlayer.Builder(this, PcmRenderersFactory(this, tap)).build()
    assetSpinner = findViewById(R.id.assetSpinner)
    waveformView = findViewById(R.id.waveformView)
    spectrumView = findViewById(R.id.spectrumView)
    seekBar = findViewById(R.id.seekBar)
    timeLabel = findViewById(R.id.timeLabel)
    statusView = findViewById(R.id.status)

    setupAssetList()
    setupControls()
  }

  private fun setupControls() {
    findViewById<MaterialButton>(R.id.playButton).setOnClickListener {
      val assetName = (assetSpinner.selectedItem as? String) ?: "sample.wav"
      playAsset(assetName)
    }

    findViewById<MaterialButton>(R.id.pauseButton).setOnClickListener {
      player.pause()
      statusView.text = "Paused"
    }

    findViewById<MaterialButton>(R.id.stopButton).setOnClickListener {
      player.stop()
      statusView.text = "Stopped"
      waveformView.reset()
      spectrumView.reset()
      seekBar.progress = 0
      timeLabel.text = "00:00 / 00:00"
    }

    seekBar.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
      override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
        if (fromUser && player.duration > 0) {
          val posMs = player.duration * progress / seekBar!!.max
          timeLabel.text = "${formatTime(posMs)} / ${formatTime(player.duration)}"
        }
      }

      override fun onStartTrackingTouch(seekBar: SeekBar?) {
        isScrubbing = true
      }

      override fun onStopTrackingTouch(seekBar: SeekBar?) {
        seekBar ?: return
        isScrubbing = false
        if (player.duration > 0) {
          val posMs = player.duration * seekBar.progress / seekBar.max
          player.seekTo(posMs)
        }
      }
    })

    assetSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
      override fun onItemSelected(
        parent: AdapterView<*>?,
        view: View?,
        position: Int,
        id: Long
      ) {
        // 选择即准备播放但不自动播放
        val assetName = parent?.getItemAtPosition(position) as? String ?: return
        prepareAsset(assetName)
      }

      override fun onNothingSelected(parent: AdapterView<*>?) {}
    }

    player.addListener(object : Player.Listener {
      override fun onPlaybackStateChanged(state: Int) {
        if (state == Player.STATE_ENDED) {
          statusView.text = "Completed"
          seekBar.progress = seekBar.max
        }
      }
    })
  }

  private fun setupAssetList() {
    val names = assets.list("")?.filter { name ->
      supportExt.any { name.lowercase().endsWith(it) }
    }?.sorted() ?: listOf("sample.wav")
    val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, names)
    adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    assetSpinner.adapter = adapter
  }

  private fun prepareAsset(assetName: String) {
    val assetUri = Uri.parse("asset:///$assetName")
    player.setMediaItem(MediaItem.fromUri(assetUri))
    player.prepare()
    statusView.text = "Ready: $assetName"
    waveformView.reset()
    spectrumView.reset()
    seekBar.progress = 0
    updateProgress()
  }

  private fun playAsset(assetName: String) {
    prepareAsset(assetName)
    player.play()
    statusView.text = "Playing: $assetName"
    handler.removeCallbacks(pollTask)
    handler.post(pollTask)
  }

  private fun updateProgress() {
    if (player.duration > 0 && !isScrubbing) {
      val pos = player.currentPosition
      seekBar.progress = (pos * seekBar.max / player.duration).toInt()
      timeLabel.text = "${formatTime(pos)} / ${formatTime(player.duration)}"
    }
  }

  private fun formatTime(ms: Long): String {
    val totalSec = ms / 1000
    val min = totalSec / 60
    val sec = totalSec % 60
    return "%02d:%02d".format(min, sec)
  }

  override fun onDestroy() {
    super.onDestroy()
    handler.removeCallbacks(pollTask)
    player.release()
  }
}
