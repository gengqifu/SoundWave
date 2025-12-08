import 'dart:async';

import 'soundwave_config.dart';
import 'audio_state.dart';
import 'soundwave_exception.dart';
import 'soundwave_player.dart';
import 'pcm_buffer.dart';
import 'spectrum_buffer.dart';
import 'export/data_exporter.dart';
import 'pcm_frame.dart';
import 'spectrum_frame.dart';

/// Dart 层控制器占位实现：封装 SoundwavePlayer，管理状态流。
class AudioController {
  AudioController({SoundwavePlayer? platform})
      : _platform = platform ?? SoundwavePlayer() {
    // ignore: avoid_print
    print('AudioController:created');
  }

  final SoundwavePlayer _platform;
  bool _initialized = false;
  StreamSubscription<dynamic>? _stateSubscription;
  PcmBuffer? _pcmBuffer;
  SpectrumBuffer? _spectrumBuffer;
  DataExporter? _exporter;
  StreamSubscription<dynamic>? _exportPcmSub;
  StreamSubscription<dynamic>? _exportSpectrumSub;
  bool _visualizationEnabled = true;

  /// 状态流（后续实现）。
  Stream<AudioState> get states => _stateController.stream;

  final StreamController<AudioState> _stateController =
      StreamController<AudioState>.broadcast();

  AudioState _state = AudioState.initial();
  AudioState get state => _state;
  PcmBuffer get pcmBuffer {
    _ensureInitialized();
    // ignore: avoid_print
    print('AudioController:pcmBuffer access');
    return _pcmBuffer!;
  }

  SpectrumBuffer get spectrumBuffer {
    _ensureInitialized();
    // ignore: avoid_print
    print('AudioController:spectrumBuffer access');
    return _spectrumBuffer!;
  }

  Future<void> init(SoundwaveConfig config) async {
    if (_initialized) {
      throw StateError('AudioController has already been initialized');
    }
    // ignore: avoid_print
    print('AudioController:init ${config.toMap()}');
    await _platform.init(config);
    _stateSubscription = _platform.stateEvents.listen(_handlePlatformEvent);
    _pcmBuffer = PcmBuffer(stream: _platform.pcmEvents, maxFrames: 60);
    _spectrumBuffer = SpectrumBuffer(stream: _platform.spectrumEvents, maxFrames: 60);
    if (config.export != null) {
      final exp = config.export!;
      _exporter = DataExporter(DataExportOptions(
        directoryPath: exp.directoryPath,
        pcmWavFileName: '${exp.filePrefix}_pcm.wav',
        spectrumCsvFileName: '${exp.filePrefix}_spectrum.csv',
        spectrumJsonFileName: '${exp.filePrefix}_spectrum.jsonl',
        sampleRate: config.sampleRate,
        channels: config.channels,
        debugEventsFileName:
            exp.enableDebugLog ? '${exp.filePrefix}_events.jsonl' : null,
      ));
      await _exporter!.init();
      if (exp.enablePcm) {
        _exportPcmSub = _platform.pcmEvents.listen(_handleExportPcm);
      }
      if (exp.enableSpectrum) {
        _exportSpectrumSub = _platform.spectrumEvents.listen(_handleExportSpectrum);
      }
    }
    _initialized = true;
    _emit(_state);
  }

  Future<void> load(String source, {Map<String, Object?>? headers}) async {
    _ensureInitialized();
    // ignore: avoid_print
    print('AudioController:load $source');
    _emit(_state.copyWith(isBuffering: true, error: null));
    await _guardPlatformCall(() => _platform.load(source, headers: headers),
        onSuccess: () {
          _resetBuffers();
          _emit(_state.copyWith(isBuffering: false));
        },
        clearBufferingOnError: true);
  }

  Future<void> play() async {
    _ensureInitialized();
    // ignore: avoid_print
    print('AudioController:play');
    await _guardPlatformCall(() => _platform.play(),
        onSuccess: () =>
            _emit(_state.copyWith(isPlaying: true, isBuffering: false, error: null)));
  }

  Future<void> pause() async {
    _ensureInitialized();
    // ignore: avoid_print
    print('AudioController:pause');
    await _guardPlatformCall(() => _platform.pause(),
        onSuccess: () =>
            _emit(_state.copyWith(isPlaying: false, isBuffering: false)));
  }

  Future<void> stop() async {
    _ensureInitialized();
    // ignore: avoid_print
    print('AudioController:stop');
    await _guardPlatformCall(() => _platform.stop(),
        onSuccess: () {
          _resetBuffers();
          _emit(_state.copyWith(
            isPlaying: false,
            isBuffering: false,
            position: Duration.zero,
            bufferedPosition: Duration.zero,
          ));
        });
  }

  Future<void> seek(Duration position) async {
    _ensureInitialized();
    // ignore: avoid_print
    print('AudioController:seek ${position.inMilliseconds}ms');
    await _guardPlatformCall(() => _platform.seek(position),
        onSuccess: () {
          _resetBuffers();
          _emit(_state.copyWith(position: position, error: null));
        });
  }

  /// 控制可视化订阅开关：关闭时暂停缓冲队列，避免 UI/后门读取。
  void setVisualizationEnabled(bool enabled) {
    _ensureInitialized();
    if (_visualizationEnabled == enabled) return;
    _visualizationEnabled = enabled;
    if (!enabled) {
      _pcmBuffer?.mute();
      _spectrumBuffer?.mute();
    } else {
      _pcmBuffer?.unmute();
      _spectrumBuffer?.unmute();
    }
  }

  void dispose() {
    _stateSubscription?.cancel();
    _pcmBuffer?.dispose();
    _spectrumBuffer?.dispose();
    _exportPcmSub?.cancel();
    _exportSpectrumSub?.cancel();
    _exporter?.close();
    _stateController.close();
  }

  Future<void> _guardPlatformCall(Future<void> Function() call,
      {void Function()? onSuccess, bool clearBufferingOnError = false}) async {
    try {
      await call();
      onSuccess?.call();
    } on SoundwaveException catch (e) {
      _emitError(e.message, clearBufferingOnError);
      rethrow;
    } on StateError catch (e) {
      _emitError(e.message, clearBufferingOnError);
      rethrow;
    } on ArgumentError catch (e) {
      _emitError(e.message, clearBufferingOnError);
      rethrow;
    }
  }

  void _handlePlatformEvent(dynamic event) {
    if (event is! Map<String, Object?>) return;
    final type = event['type'];
    if (type == 'state') {
      _emit(_state.copyWith(
        position: _parseDuration(event['positionMs'], _state.position),
        duration: _parseDuration(event['durationMs'], _state.duration),
        bufferedPosition:
            _parseDuration(event['bufferedMs'], _state.bufferedPosition ?? Duration.zero),
        isPlaying: (event['isPlaying'] as bool?) ?? _state.isPlaying,
        isBuffering: (event['isBuffering'] as bool?) ?? _state.isBuffering,
        levels: _parseDoubleList(event['levels']) ?? _state.levels,
        spectrum: _parseDoubleList(event['spectrum']) ?? _state.spectrum,
        error: null,
      ));
    } else if (type == 'buffering') {
      _emit(_state.copyWith(
        bufferedPosition:
            _parseDuration(event['bufferedMs'], _state.bufferedPosition ?? Duration.zero),
        isBuffering: (event['isBuffering'] as bool?) ?? true,
        error: null,
      ));
    } else if (type == 'retry') {
      final message = event['message'] as String? ?? 'Retrying';
      _emit(_state.copyWith(
          error: message,
          isBuffering: (event['isBuffering'] as bool?) ?? true,
          bufferedPosition:
              _parseDuration(event['bufferedMs'], _state.bufferedPosition ?? Duration.zero)));
    } else if (type == 'stalled') {
      _emit(_state.copyWith(
        isBuffering: true,
        error: (event['message'] as String?) ?? _state.error,
      ));
    } else if (type == 'focusLost') {
      final message = event['message'] as String? ?? 'Audio focus lost';
      _emit(_state.copyWith(
        isPlaying: false,
        isBuffering: true,
        error: message,
      ));
      _pcmBuffer?.pause();
      _spectrumBuffer?.pause();
    } else if (type == 'resumedFromBackground') {
      _emit(_state.copyWith(
        isPlaying: true,
        isBuffering: false,
        position: _parseDuration(event['positionMs'], _state.position),
        bufferedPosition:
            _parseDuration(event['bufferedMs'], _state.bufferedPosition ?? Duration.zero),
        error: null,
      ));
      _pcmBuffer?.resume();
      _spectrumBuffer?.resume();
    } else if (type == 'resumed') {
      _emit(_state.copyWith(
        isBuffering: false,
        position: _parseDuration(event['positionMs'], _state.position),
        bufferedPosition:
            _parseDuration(event['bufferedMs'], _state.bufferedPosition ?? Duration.zero),
        error: null,
      ));
    } else if (type == 'error') {
      final message = event['message'] as String? ?? 'Unknown error';
      _emit(_state.copyWith(error: message));
    }
  }

  void _handleExportPcm(dynamic event) {
    if (event is! Map) return;
    final samplesRaw = event['samples'];
    final seq = (event['sequence'] as num?)?.toInt();
    final ts = (event['timestampMs'] as num?)?.toInt();
    if (seq == null || ts == null || samplesRaw is! List) return;
    final samples = samplesRaw.whereType<num>().map((n) => n.toDouble()).toList(growable: false);
    _exporter?.addPcmFrame(PcmFrame(sequence: seq, timestampMs: ts, samples: samples));
  }

  void _handleExportSpectrum(dynamic event) {
    if (event is! Map) return;
    final binsRaw = event['bins'];
    final seq = (event['sequence'] as num?)?.toInt();
    final ts = (event['timestampMs'] as num?)?.toInt();
    final binHz = (event['binHz'] as num?)?.toDouble() ?? 0.0;
    if (seq == null || ts == null || binsRaw is! List) return;
    final bins = binsRaw.whereType<num>().map((n) => n.toDouble()).toList(growable: false);
    _exporter?.addSpectrumFrame(
        SpectrumFrame(sequence: seq, timestampMs: ts, bins: bins, binHz: binHz));
  }

  void _emit(AudioState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _emitError(String message, bool clearBuffering) {
    _emit(_state.copyWith(
        error: message, isBuffering: clearBuffering ? false : _state.isBuffering));
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('AudioController has not been initialized');
    }
  }

  Duration _parseDuration(Object? raw, Duration fallback) {
    if (raw is int) return Duration(milliseconds: raw);
    if (raw is num) return Duration(milliseconds: raw.toInt());
    return fallback;
  }

  List<double>? _parseDoubleList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<num>()
          .map((n) => n.toDouble())
          .toList(growable: false);
    }
    return null;
  }

  void _resetBuffers() {
    _pcmBuffer?.reset();
    _spectrumBuffer?.reset();
  }
}
