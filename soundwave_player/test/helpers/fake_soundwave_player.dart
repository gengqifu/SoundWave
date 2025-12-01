import 'dart:async';

import 'package:soundwave_player/soundwave_player.dart';

class FakePlatform extends SoundwavePlayer {
  FakePlatform({this.shouldThrow = false, this.throwError}) : super();

  bool shouldThrow;
  SoundwaveException? throwError;
  final StreamController<Map<String, Object?>> _stateController =
      StreamController<Map<String, Object?>>.broadcast();
  final StreamController<Map<String, Object?>> _pcmController =
      StreamController<Map<String, Object?>>.broadcast();
  final StreamController<Map<String, Object?>> _spectrumController =
      StreamController<Map<String, Object?>>.broadcast();

  List<String> calls = [];

  @override
  Future<void> init(SoundwaveConfig config) async {
    calls.add('init');
    if (shouldThrow) throw StateError('init failed');
  }

  @override
  Future<void> load(String source, {Map<String, Object?>? headers}) async {
    calls.add('load');
    if (shouldThrow) {
      if (throwError != null) throw throwError!;
      throw StateError('load failed');
    }
  }

  @override
  Future<void> play() async {
    calls.add('play');
    if (shouldThrow) throw StateError('play failed');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    if (shouldThrow) throw StateError('pause failed');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek');
  }

  @override
  Stream<dynamic> get stateEvents => _stateController.stream;
  @override
  Stream<dynamic> get pcmEvents => _pcmController.stream;
  @override
  Stream<dynamic> get spectrumEvents => _spectrumController.stream;

  void emitState(Map<String, Object?> event) {
    _stateController.add(event);
  }

  void emitPcm(Map<String, Object?> event) {
    _pcmController.add(event);
  }

  void emitSpectrum(Map<String, Object?> event) {
    _spectrumController.add(event);
  }

  void dispose() {
    _stateController.close();
    _pcmController.close();
    _spectrumController.close();
  }
}
