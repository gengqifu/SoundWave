package com.soundwave.soundwave_player

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import android.util.Log
import java.util.concurrent.ConcurrentHashMap

class SoundwavePlayerPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler,
    AudioManager.OnAudioFocusChangeListener {
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var stateChannel: EventChannel
    private var stateSink: EventChannel.EventSink? = null

    private var player: ExoPlayer? = null
    private var httpFactory: DefaultHttpDataSource.Factory? = null
    private var headers: Map<String, String> = emptyMap()
    private var audioManager: AudioManager? = null
    private var hasFocus: Boolean = false
    private var serviceStarted: Boolean = false

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)

        stateChannel = EventChannel(binding.binaryMessenger, "$EVENT_PREFIX/state")
        stateChannel.setStreamHandler(this)

        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        Log.d(TAG, "attachedToEngine")
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        stateChannel.setStreamHandler(null)
        releasePlayer()
        stopService()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "init" -> {
                Log.d(TAG, "method:init args=${call.arguments}")
                initPlayer(call, result)
            }
            "load" -> {
                Log.d(TAG, "method:load args=${call.arguments}")
                load(call, result)
            }
            "play" -> {
                Log.d(TAG, "method:play")
                player?.play()
                startService()
                result.success(null)
            }
            "pause" -> {
                Log.d(TAG, "method:pause")
                player?.pause()
                result.success(null)
            }
            "stop" -> {
                Log.d(TAG, "method:stop")
                player?.stop()
                stopService()
                result.success(null)
            }
            "seek" -> {
                val pos = (call.argument<Int>("positionMs") ?: 0).toLong()
                Log.d(TAG, "method:seek pos=$pos")
                player?.seekTo(pos)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun initPlayer(call: MethodCall, result: Result) {
        releasePlayer()
        abandonFocus()
        val config = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val network = config["network"] as? Map<*, *>
        val connectTimeout =
            (network?.get("connectTimeoutMs") as? Number)?.toInt() ?: DefaultHttpDataSource.DEFAULT_CONNECT_TIMEOUT_MILLIS
        val readTimeout =
            (network?.get("readTimeoutMs") as? Number)?.toInt() ?: DefaultHttpDataSource.DEFAULT_READ_TIMEOUT_MILLIS

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

        player = ExoPlayer.Builder(context).build().also { exo ->
            Log.d(
                TAG,
                "initPlayer connectTimeout=$connectTimeout readTimeout=$readTimeout headers=${headers.keys}"
            )
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
                                "type" to "resumed",
                                "isBuffering" to false,
                                "positionMs" to exo.currentPosition,
                                "bufferedMs" to exo.bufferedPosition
                            )
                        )
                        Player.STATE_ENDED -> emitState(
                            mapOf(
                                "type" to "state",
                                "isPlaying" to false,
                                "positionMs" to exo.currentPosition,
                                "durationMs" to exo.duration,
                                "bufferedMs" to exo.bufferedPosition
                            )
                        )
                        else -> {}
                    }
                    Log.d(TAG, "state=$playbackState pos=${exo.currentPosition} buffered=${exo.bufferedPosition}")
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
        val mediaItem = MediaItem.Builder()
            .setUri(source)
            .build()
        val mediaSource = if (uri.toString().endsWith(".m3u8", ignoreCase = true)) {
            HlsMediaSource.Factory(dataSourceFactory).createMediaSource(mediaItem)
        } else {
            ProgressiveMediaSource.Factory(dataSourceFactory).createMediaSource(mediaItem)
        }

        val exo = player ?: run {
            result.error("invalid_state", "Player not initialized", null); return
        }
        Log.d(TAG, "load source=$source scheme=${uri.scheme} range=[$rangeStart,$rangeEnd] headers=${headers.keys}")
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
    }

    private fun startService() {
        if (serviceStarted) return
        val intent = Intent(context, ForegroundAudioService::class.java)
        context.startForegroundService(intent)
        serviceStarted = true
        Log.d(TAG, "foreground service started")
    }

    private fun stopService() {
        if (!serviceStarted) return
        val intent = Intent(context, ForegroundAudioService::class.java)
        context.stopService(intent)
        serviceStarted = false
        Log.d(TAG, "foreground service stopped")
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
        Log.d(TAG, "requestAudioFocus result=$result granted=$hasFocus")
    }

    private fun abandonFocus() {
        audioManager?.abandonAudioFocus(this)
        hasFocus = false
        Log.d(TAG, "abandonAudioFocus")
    }

    override fun onAudioFocusChange(focusChange: Int) {
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
        Log.d(TAG, "audioFocusChange=$focusChange playing=${player?.isPlaying}")
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        stateSink = events
    }

    override fun onCancel(arguments: Any?) {
        stateSink = null
    }

    companion object {
        private const val METHOD_CHANNEL_NAME = "soundwave_player"
        private const val EVENT_PREFIX = "soundwave_player/events"
        private const val TAG = "Soundwave"
    }
}
