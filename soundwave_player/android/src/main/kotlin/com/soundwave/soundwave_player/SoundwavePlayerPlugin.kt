package com.soundwave.soundwave_player

import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ConcurrentHashMap

class SoundwavePlayerPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var stateChannel: EventChannel
    private var stateSink: EventChannel.EventSink? = null

    private var player: ExoPlayer? = null
    private var httpFactory: DefaultHttpDataSource.Factory? = null
    private var headers: Map<String, String> = emptyMap()

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)

        stateChannel = EventChannel(binding.binaryMessenger, "$EVENT_PREFIX/state")
        stateChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        stateChannel.setStreamHandler(null)
        releasePlayer()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "init" -> {
                initPlayer(call, result)
            }
            "load" -> {
                load(call, result)
            }
            "play" -> {
                player?.play()
                result.success(null)
            }
            "pause" -> {
                player?.pause()
                result.success(null)
            }
            "stop" -> {
                player?.stop()
                result.success(null)
            }
            "seek" -> {
                val pos = (call.argument<Int>("positionMs") ?: 0).toLong()
                player?.seekTo(pos)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun initPlayer(call: MethodCall, result: Result) {
        releasePlayer()
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
                }

                override fun onPlayerError(error: PlaybackException) {
                    emitState(
                        mapOf(
                            "type" to "error",
                            "message" to (error.message ?: "playback error"),
                            "code" to error.errorCodeName
                        )
                    )
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

        val dsFactory = httpFactory ?: DefaultHttpDataSource.Factory()
        val mediaItemBuilder = MediaItem.Builder()
            .setUri(source)
        if (headers.isNotEmpty()) {
            val props = ConcurrentHashMap<String, String>()
            props.putAll(headers)
            mediaItemBuilder.setRequestMetadata(
                MediaItem.RequestMetadata.Builder().setHttpRequestHeaders(props).build()
            )
        }
        if (rangeStart != null) {
            val end = rangeEnd ?: -1
            dsFactory.setDefaultRequestProperties(
                mapOf("Range" to "bytes=$rangeStart-${if (end >= 0) end else ""}")
            )
        }
        val mediaItem = mediaItemBuilder.build()
        val sourceFactory = HlsMediaSource.Factory(dsFactory)
        val mediaSource = sourceFactory.createMediaSource(mediaItem)

        val exo = player ?: run {
            result.error("invalid_state", "Player not initialized", null); return
        }
        exo.setMediaSource(mediaSource)
        exo.prepare()
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

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        stateSink = events
    }

    override fun onCancel(arguments: Any?) {
        stateSink = null
    }

    companion object {
        private const val METHOD_CHANNEL_NAME = "soundwave_player"
        private const val EVENT_PREFIX = "soundwave_player/events"
    }
}
