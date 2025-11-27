import 'dart:async';

import 'package:soundwave_player/soundwave_player.dart';

class FakePlatform extends SoundwavePlayer {
  FakePlatform({this.shouldThrow = false}) : super();

  bool shouldThrow;
  final StreamController<Map<String, Object?>> _stateController =
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
    if (shouldThrow) throw StateError('load failed');
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

  void emitState(Map<String, Object?> event) {
    _stateController.add(event);
  }

  void dispose() {
    _stateController.close();
  }
}
