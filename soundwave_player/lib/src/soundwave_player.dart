import 'package:flutter/services.dart';

import 'soundwave_config.dart';
import 'soundwave_exception.dart';

/// Platform-agnostic API for the SoundWave plugin.
class SoundwavePlayer {
  SoundwavePlayer({BinaryMessenger? messenger})
      : _methodChannel = MethodChannel(_methodChannelName, const StandardMethodCodec(), messenger),
        _stateChannel = EventChannel('$_eventPrefix/state', const StandardMethodCodec(), messenger),
        _pcmChannel = EventChannel('$_eventPrefix/pcm', const StandardMethodCodec(), messenger),
        _spectrumChannel = EventChannel('$_eventPrefix/spectrum', const StandardMethodCodec(), messenger);

  static const String _methodChannelName = 'soundwave_player';
  static const String _eventPrefix = 'soundwave_player/events';

  final MethodChannel _methodChannel;
  final EventChannel _stateChannel;
  final EventChannel _pcmChannel;
  final EventChannel _spectrumChannel;
  bool _initialized = false;

  Stream<dynamic> get stateEvents => _stateChannel.receiveBroadcastStream();
  Stream<dynamic> get pcmEvents => _pcmChannel.receiveBroadcastStream();
  Stream<dynamic> get spectrumEvents => _spectrumChannel.receiveBroadcastStream();

  Future<void> init(SoundwaveConfig config) async {
    if (_initialized) {
      throw StateError('SoundwavePlayer has already been initialized');
    }
    config.validate();
    await _invoke<void>('init', config.toMap());
    _initialized = true;
  }

  Future<void> load(String source, {Map<String, Object?>? headers}) async {
    _ensureInitialized();
    if (source.trim().isEmpty) {
      throw ArgumentError.value(source, 'source', 'cannot be empty');
    }
    await _invoke<void>('load', <String, Object?>{
      'source': source,
      if (headers != null) 'headers': headers,
    });
  }

  Future<void> play() {
    _ensureInitialized();
    return _invoke<void>('play');
  }

  Future<void> pause() {
    _ensureInitialized();
    return _invoke<void>('pause');
  }

  Future<void> stop() {
    _ensureInitialized();
    return _invoke<void>('stop');
  }

  Future<void> seek(Duration position) async {
    _ensureInitialized();
    if (position.isNegative) {
      throw ArgumentError.value(position, 'position', 'must be >= 0');
    }
    await _invoke<void>('seek', <String, Object?>{'positionMs': position.inMilliseconds});
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _methodChannel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw SoundwaveException(e.code, e.message ?? 'Unknown error', e.details);
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('SoundwavePlayer has not been initialized');
    }
  }
}
