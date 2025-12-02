package com.soundwave.player

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** SoundwavePlayerPlugin */
class SoundwavePlayerPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var methodChannel: MethodChannel
  private lateinit var stateEventChannel: EventChannel
  private lateinit var pcmEventChannel: EventChannel
  private lateinit var spectrumEventChannel: EventChannel

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    log("onAttachedToEngine")
    methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
    methodChannel.setMethodCallHandler(this)

    stateEventChannel = EventChannel(binding.binaryMessenger, "$EVENT_PREFIX/state")
    pcmEventChannel = EventChannel(binding.binaryMessenger, "$EVENT_PREFIX/pcm")
    spectrumEventChannel = EventChannel(binding.binaryMessenger, "$EVENT_PREFIX/spectrum")

    stateEventChannel.setStreamHandler(this)
    pcmEventChannel.setStreamHandler(this)
    spectrumEventChannel.setStreamHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    log("onDetachedFromEngine")
    methodChannel.setMethodCallHandler(null)
    stateEventChannel.setStreamHandler(null)
    pcmEventChannel.setStreamHandler(null)
    spectrumEventChannel.setStreamHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    log("onMethodCall ${call.method}")
    when (call.method) {
      "init",
      "load",
      "play",
      "pause",
      "stop",
      "seek" -> {
        // Placeholder: succeed without doing anything yet
        result.success(null)
      }

      else -> result.notImplemented()
    }
  }

  // EventChannel.StreamHandler placeholders
  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    log("onListen ${arguments ?: "null"}")
    // No-op placeholder stream; actual event emission will be added in later tasks.
  }

  override fun onCancel(arguments: Any?) {
    log("onCancel ${arguments ?: "null"}")
    // No-op
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
