import 'package:flutter/services.dart';

import 'soundwave_config.dart';
import 'soundwave_exception.dart';
import 'pcm_input_frame.dart';

/// Platform-agnostic API for the SoundWave plugin.
class SoundwavePlayer {
  SoundwavePlayer({BinaryMessenger? messenger})
      : _methodChannel = MethodChannel(
            _methodChannelName, const StandardMethodCodec(), messenger),
        _stateChannel = EventChannel(
            '$_eventPrefix/state', const StandardMethodCodec(), messenger),
        _pcmChannel = EventChannel(
            '$_eventPrefix/pcm', const StandardMethodCodec(), messenger),
        _spectrumChannel = EventChannel(
            '$_eventPrefix/spectrum', const StandardMethodCodec(), messenger);

  static const String _methodChannelName = 'soundwave_player';
  static const String _eventPrefix = 'soundwave_player/events';

  final MethodChannel _methodChannel;
  final EventChannel _stateChannel;
  final EventChannel _pcmChannel;
  final EventChannel _spectrumChannel;
  bool _initialized = false;

  Stream<dynamic> get stateEvents => _stateChannel.receiveBroadcastStream();
  Stream<dynamic> get pcmEvents => _pcmChannel.receiveBroadcastStream();
  Stream<dynamic> get spectrumEvents =>
      _spectrumChannel.receiveBroadcastStream();

  Future<void> init(SoundwaveConfig config) async {
    if (_initialized) {
      throw StateError('SoundwavePlayer has already been initialized');
    }
    config.validate();
    // Log initialization path for troubleshooting.
    // ignore: avoid_print
    print('SoundwavePlayer:init ${config.toMap()}');
    await _invoke<void>('init', config.toMap());
    _initialized = true;
  }

  Future<void> load(String source,
      {Map<String, Object?>? headers, int? rangeStart, int? rangeEnd}) async {
    _ensureInitialized();
    if (source.trim().isEmpty) {
      throw ArgumentError.value(source, 'source', 'cannot be empty');
    }
    // allow http/https/file/relative paths for backward compatibility.
    final uri = Uri.tryParse(source);
    if (uri == null ||
        (!uri.isScheme('http') &&
            !uri.isScheme('https') &&
            !uri.isScheme('file') &&
            uri.scheme.isNotEmpty)) {
      throw ArgumentError.value(source, 'source', 'unsupported scheme');
    }
    if (rangeStart != null && rangeStart < 0) {
      throw ArgumentError.value(rangeStart, 'rangeStart', 'must be >= 0');
    }
    if (rangeEnd != null && rangeEnd < 0) {
      throw ArgumentError.value(rangeEnd, 'rangeEnd', 'must be >= 0');
    }
    if (rangeStart != null && rangeEnd != null && rangeEnd < rangeStart) {
      throw ArgumentError.value(rangeEnd, 'rangeEnd', 'must be >= rangeStart');
    }
    // ignore: avoid_print
    print('SoundwavePlayer:load source=$source range=[$rangeStart,$rangeEnd] headers=${headers?.keys}');
    await _invoke<void>('load', <String, Object?>{
      'source': source,
      if (headers != null) 'headers': headers,
      if (rangeStart != null || rangeEnd != null)
        'range': <String, Object?>{
          if (rangeStart != null) 'start': rangeStart,
          if (rangeEnd != null) 'end': rangeEnd,
        },
    });
  }

  Future<void> play() {
    _ensureInitialized();
    // ignore: avoid_print
    print('SoundwavePlayer:play');
    return _invoke<void>('play');
  }

  Future<void> pause() {
    _ensureInitialized();
    // ignore: avoid_print
    print('SoundwavePlayer:pause');
    return _invoke<void>('pause');
  }

  Future<void> stop() {
    _ensureInitialized();
    // ignore: avoid_print
    print('SoundwavePlayer:stop');
    return _invoke<void>('stop');
  }

  Future<void> seek(Duration position) async {
    _ensureInitialized();
    if (position.isNegative) {
      throw ArgumentError.value(position, 'position', 'must be >= 0');
    }
    // ignore: avoid_print
    print('SoundwavePlayer:seek ${position.inMilliseconds}ms');
    await _invoke<void>(
        'seek', <String, Object?>{'positionMs': position.inMilliseconds});
  }

  Future<T?> _invoke<T>(String method,
      [Map<String, Object?>? arguments]) async {
    try {
      return await _methodChannel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw SoundwaveException(e.code, e.message ?? 'Unknown error', e.details);
    }
  }

  Future<void> pushPcmFrame(PcmInputFrame frame) async {
    _ensureInitialized();
    if (frame.sampleRate <= 0) {
      throw ArgumentError.value(frame.sampleRate, 'sampleRate', 'must be > 0');
    }
    if (frame.channels <= 0) {
      throw ArgumentError.value(frame.channels, 'channels', 'must be > 0');
    }
    if (frame.samples.isEmpty) {
      throw ArgumentError.value(frame.samples, 'samples', 'cannot be empty');
    }
    if (frame.samples.length % frame.channels != 0) {
      throw ArgumentError.value(
          frame.samples.length, 'samples', 'must be divisible by channels');
    }
    if (frame.timestampMs < 0) {
      throw ArgumentError.value(frame.timestampMs, 'timestampMs', 'must be >= 0');
    }
    if (frame.sequence < 0) {
      throw ArgumentError.value(frame.sequence, 'sequence', 'must be >= 0');
    }
    // ignore: avoid_print
    print('SoundwavePlayer:pushPcmFrame seq=${frame.sequence} ts=${frame.timestampMs}');
    await _invoke<void>('pushPcmFrame', frame.toMap());
  }

  Future<void> subscribeWaveform() {
    _ensureInitialized();
    return _invoke<void>('subscribeWaveform');
  }

  Future<void> subscribeSpectrum() {
    _ensureInitialized();
    return _invoke<void>('subscribeSpectrum');
  }

  Future<void> unsubscribeWaveform() {
    _ensureInitialized();
    return _invoke<void>('unsubscribeWaveform');
  }

  Future<void> unsubscribeSpectrum() {
    _ensureInitialized();
    return _invoke<void>('unsubscribeSpectrum');
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('SoundwavePlayer has not been initialized');
    }
  }
}
