package com.soundwave.player

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.audio.DefaultAudioSink
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import androidx.media3.common.util.UnstableApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ConcurrentHashMap

/** SoundwavePlayerPlugin */
@UnstableApi
class SoundwavePlayerPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var context: Context
  private lateinit var methodChannel: MethodChannel
  private lateinit var stateEventChannel: EventChannel
  private lateinit var pcmEventChannel: EventChannel
  private lateinit var spectrumEventChannel: EventChannel

  private var stateSink: EventChannel.EventSink? = null
  private var pcmSink: EventChannel.EventSink? = null
  private var spectrumSink: EventChannel.EventSink? = null

  private var player: ExoPlayer? = null
  private var httpFactory: DefaultHttpDataSource.Factory? = null
  private var headers: Map<String, String> = emptyMap()
  private var audioManager: AudioManager? = null
  private var hasFocus: Boolean = false
  private var serviceStarted: Boolean = false
  private val pcmProcessor = PcmTapProcessor()
  private var sampleRate: Int = 48000
  private var pcmWorker: HandlerThread? = null
  private var pcmHandler: Handler? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
    methodChannel.setMethodCallHandler(this)

    stateEventChannel = EventChannel(binding.binaryMessenger, "$EVENT_PREFIX/state")
    pcmEventChannel = EventChannel(binding.binaryMessenger, "$EVENT_PREFIX/pcm")
    spectrumEventChannel = EventChannel(binding.binaryMessenger, "$EVENT_PREFIX/spectrum")

    stateEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        stateSink = events
        log("state onListen $arguments")
      }

      override fun onCancel(arguments: Any?) {
        stateSink = null
        log("state onCancel $arguments")
      }
    })
    pcmEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        pcmSink = events
        log("pcm onListen $arguments")
      }

      override fun onCancel(arguments: Any?) {
        pcmSink = null
        log("pcm onCancel $arguments")
      }
    })
    spectrumEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        spectrumSink = events
        log("spectrum onListen $arguments")
      }

      override fun onCancel(arguments: Any?) {
        spectrumSink = null
        log("spectrum onCancel $arguments")
      }
    })

    audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    log("onAttachedToEngine")
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    stateEventChannel.setStreamHandler(null)
    pcmEventChannel.setStreamHandler(null)
    spectrumEventChannel.setStreamHandler(null)
    releasePlayer()
    stopService()
    stopPcmLoop()
    log("onDetachedFromEngine")
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    log("onMethodCall ${call.method}")
    when (call.method) {
      "init" -> initPlayer(call, result)
      "load" -> {
        resetPcm()
        stopPcmLoop()
        load(call, result)
      }
      "play" -> {
        player?.play()
        startService()
        startPcmLoop()
        result.success(null)
      }
      "pause" -> {
        player?.pause()
        stopPcmLoop()
        result.success(null)
      }
      "stop" -> {
        player?.stop()
        stopService()
        resetPcm()
        stopPcmLoop()
        result.success(null)
      }
      "seek" -> {
        val pos = (call.argument<Int>("positionMs") ?: 0).toLong()
        player?.seekTo(pos)
        resetPcm()
        stopPcmLoop()
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  private fun initPlayer(call: MethodCall, result: Result) {
    releasePlayer()
    abandonFocus()
    stopPcmLoop()
    stopPcmLoop()
    val config = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
    sampleRate = (config["sampleRate"] as? Number)?.toInt() ?: sampleRate
    val network = config["network"] as? Map<*, *>
    val connectTimeout =
      (network?.get("connectTimeoutMs") as? Number)?.toInt()
        ?: DefaultHttpDataSource.DEFAULT_CONNECT_TIMEOUT_MILLIS
    val readTimeout =
      (network?.get("readTimeoutMs") as? Number)?.toInt()
        ?: DefaultHttpDataSource.DEFAULT_READ_TIMEOUT_MILLIS

    headers = (network?.get("headers") as? Map<*, *>)?.mapNotNull {
      val key = it.key?.toString() ?: return@mapNotNull null
      val value = it.value?.toString() ?: return@mapNotNull null
      key to value
    }?.toMap() ?: emptyMap()

    httpFactory = DefaultHttpDataSource.Factory()
      .setConnectTimeoutMs(connectTimeout)
      .setReadTimeoutMs(readTimeout)
      .setAllowCrossProtocolRedirects(true)
    if (headers.isNotEmpty()) {
      httpFactory?.setDefaultRequestProperties(headers)
    }

    val audioSink = DefaultAudioSink.Builder()
      .setAudioProcessors(arrayOf(pcmProcessor))
      .build()

    player = ExoPlayer.Builder(context)
      .setRenderersFactory(DefaultRenderersFactory(context))
      .setAudioSink(audioSink)
      .build().also { exo ->
      log("initPlayer connect=$connectTimeout read=$readTimeout headers=${headers.keys}")
      exo.addListener(object : Player.Listener {
        override fun onPlaybackStateChanged(playbackState: Int) {
          when (playbackState) {
            Player.STATE_BUFFERING -> emitState(
              mapOf(
                "type" to "buffering",
                "isBuffering" to true,
                "bufferedMs" to exo.bufferedPosition
              )
            )
            Player.STATE_READY -> emitState(
              mapOf(
                "type" to "ready",
                "isBuffering" to false,
                "durationMs" to exo.duration
              )
            )
            Player.STATE_ENDED -> emitState(
              mapOf(
                "type" to "completed",
                "isPlaying" to false,
                "positionMs" to exo.currentPosition,
                "durationMs" to exo.duration,
                "bufferedMs" to exo.bufferedPosition
              )
            )
            else -> {}
          }
          emitState(
            mapOf(
              "type" to "state",
              "state" to playbackState,
              "positionMs" to exo.currentPosition,
              "bufferedMs" to exo.bufferedPosition,
              "durationMs" to exo.duration
            )
          )
          log("state=$playbackState pos=${exo.currentPosition} buffered=${exo.bufferedPosition}")
        }

        override fun onPlayerError(error: PlaybackException) {
          emitState(
            mapOf(
              "type" to "error",
              "message" to (error.message ?: "playback error"),
              "code" to error.errorCodeName
            )
          )
          Log.e(TAG, "playerError code=${error.errorCodeName}", error)
        }

        override fun onIsPlayingChanged(isPlaying: Boolean) {
          emitState(
            mapOf(
              "type" to "state",
              "isPlaying" to isPlaying,
              "positionMs" to exo.currentPosition,
              "bufferedMs" to exo.bufferedPosition,
              "durationMs" to exo.duration
            )
          )
        }
      })
    }
    result.success(null)
  }

  private fun load(call: MethodCall, result: Result) {
    val source = call.argument<String>("source") ?: run {
      result.error("invalid_args", "source is required", null)
      return
    }
    val range = call.argument<Map<String, Any?>>("range") ?: emptyMap()
    val rangeStart = (range["start"] as? Number)?.toLong()
    val rangeEnd = (range["end"] as? Number)?.toLong()

    val uri = Uri.parse(source)
    val httpDsFactory = (httpFactory ?: DefaultHttpDataSource.Factory())
    if (headers.isNotEmpty()) {
      httpDsFactory.setDefaultRequestProperties(headers)
    }
    if (rangeStart != null) {
      val end = rangeEnd ?: -1
      httpDsFactory.setDefaultRequestProperties(
        mapOf("Range" to "bytes=$rangeStart-${if (end >= 0) end else ""}")
      )
    }
    val dataSourceFactory: DataSource.Factory =
      DefaultDataSource.Factory(context, httpDsFactory)
    val mediaItem = MediaItem.Builder().setUri(source).build()
    val mediaSource = if (uri.toString().endsWith(".m3u8", ignoreCase = true)) {
      HlsMediaSource.Factory(dataSourceFactory).createMediaSource(mediaItem)
    } else {
      ProgressiveMediaSource.Factory(dataSourceFactory).createMediaSource(mediaItem)
    }

    val exo = player ?: run {
      result.error("invalid_state", "Player not initialized", null); return
    }
    log("load source=$source scheme=${uri.scheme} range=[$rangeStart,$rangeEnd] headers=${headers.keys}")
    exo.setMediaSource(mediaSource)
    exo.prepare()
    requestFocus()
    emitState(mapOf("type" to "state", "isPlaying" to false, "bufferedMs" to 0))
    result.success(null)
  }

  private fun emitState(event: Map<String, Any?>) {
    stateSink?.success(event)
  }

  private fun releasePlayer() {
    player?.release()
    player = null
    pcmProcessor.onReset()
  }

  private fun startService() {
    if (serviceStarted) return
    val intent = Intent(context, ForegroundAudioService::class.java)
    context.startForegroundService(intent)
    serviceStarted = true
    log("foreground service started")
  }

  private fun stopService() {
    if (!serviceStarted) return
    val intent = Intent(context, ForegroundAudioService::class.java)
    context.stopService(intent)
    serviceStarted = false
    log("foreground service stopped")
  }

  // Audio focus
  private fun requestFocus() {
    val am = audioManager ?: return
    val result = am.requestAudioFocus(
      { focusChange -> onAudioFocusChange(focusChange) },
      AudioManager.STREAM_MUSIC,
      AudioManager.AUDIOFOCUS_GAIN
    )
    hasFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    log("requestAudioFocus result=$result granted=$hasFocus")
  }

  private fun abandonFocus() {
    audioManager?.abandonAudioFocus { onAudioFocusChange(it) }
    hasFocus = false
    log("abandonAudioFocus")
  }

  private fun onAudioFocusChange(focusChange: Int) {
    when (focusChange) {
      AudioManager.AUDIOFOCUS_LOSS -> {
        player?.pause()
        emitState(mapOf("type" to "focusLost", "message" to "Audio focus lost"))
      }
      AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
        player?.pause()
        emitState(mapOf("type" to "focusLost", "message" to "Audio focus transient loss"))
      }
      AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
        player?.volume = 0.2f
        emitState(mapOf("type" to "focusLost", "message" to "Ducking"))
      }
      AudioManager.AUDIOFOCUS_GAIN -> {
        player?.volume = 1.0f
        emitState(
          mapOf(
            "type" to "resumedFromBackground",
            "positionMs" to (player?.currentPosition ?: 0),
            "bufferedMs" to (player?.bufferedPosition ?: 0)
          )
        )
      }
    }
    log("audioFocusChange=$focusChange playing=${player?.isPlaying}")
  }

  private fun startPcmLoop() {
    if (pcmWorker == null) {
      pcmWorker = HandlerThread("pcm-push").also { it.start() }
      pcmHandler = Handler(pcmWorker!!.looper)
    }
    pcmHandler?.removeCallbacksAndMessages(null)
    pcmHandler?.post(pcmPushRunnable)
    log("pcmLoop started")
  }

  private fun stopPcmLoop() {
    pcmHandler?.removeCallbacksAndMessages(null)
    pcmWorker?.quitSafely()
    pcmWorker = null
    pcmHandler = null
    log("pcmLoop stopped")
  }

  private val pcmPushRunnable = object : Runnable {
    override fun run() {
      val frames = pcmProcessor.drain(5)
      val dropped = pcmProcessor.droppedSinceLastDrain()
      if (frames.isNotEmpty()) {
        frames.forEach { frame ->
          val ts = player?.currentPosition ?: frame.timestampMs
          pcmSink?.success(
            mapOf(
              "sequence" to frame.sequence,
              "timestampMs" to ts,
              "samples" to frame.samples.toList(),
              "droppedBefore" to dropped
            )
          )
          val spectrum = computeSpectrum(frame.samples)
          if (spectrum != null) {
            spectrumSink?.success(
              mapOf(
                "sequence" to frame.sequence,
                "timestampMs" to ts,
                "bins" to spectrum.first.toList(),
                "binHz" to spectrum.second
              )
            )
          }
        }
      } else if (dropped > 0) {
        notifyDropped(dropped)
      }
      pcmHandler?.postDelayed(this, 1000L / 30L)
    }
  }

  private fun resetPcm() {
    val dropped = pcmProcessor.droppedSinceLastDrain()
    pcmProcessor.onReset()
    notifyDropped(dropped)
    log("pcm reset")
  }

  private fun notifyDropped(dropped: Int) {
    if (dropped <= 0) return
    pcmSink?.success(mapOf("dropped" to true, "droppedBefore" to dropped))
    spectrumSink?.success(mapOf("dropped" to true, "droppedBefore" to dropped))
  }

  private fun computeSpectrum(samples: FloatArray): Pair<FloatArray, Double>? {
    val n = 1024
    if (samples.isEmpty()) return null
    val re = FloatArray(n)
    val im = FloatArray(n)
    val len = minOf(samples.size, n)
    // Hann window and copy
    for (i in 0 until len) {
      val w = 0.5f * (1f - cos((2.0 * PI * i) / (n - 1)).toFloat())
      re[i] = samples[i] * w
    }
    // bit reversal
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
    // iterative Cooley-Tukey FFT (radix-2)
    var lenM = 2
    while (lenM <= n) {
      val angle = -2.0 * PI / lenM
      val wLenRe = cos(angle)
      val wLenIm = sin(angle)
      for (k in 0 until n step lenM) {
        var wRe = 1.0
        var wIm = 0.0
        for (m in 0 until lenM / 2) {
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
        }
      }
      lenM = lenM shl 1
    }
    val bins = FloatArray(n / 2)
    for (i in bins.indices) {
      bins[i] = hypot(re[i].toDouble(), im[i].toDouble()).toFloat()
    }
    val binHz = sampleRate.toDouble() / n
    return bins to binHz
  }
  }

  companion object {
    private const val METHOD_CHANNEL_NAME = "soundwave_player"
    private const val EVENT_PREFIX = "soundwave_player/events"
    private const val TAG = "Soundwave"
  }

  private fun log(msg: String) {
    Log.i(TAG, msg)
    println("Soundwave: $msg")
  }
}
