import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

import 'helpers/fake_soundwave_player.dart';

void main() {
  group('AudioController', () {
    late FakePlatform platform;
    late AudioController controller;

    setUp(() {
      platform = FakePlatform();
      controller = AudioController(platform: platform);
    });

    tearDown(() {
      controller.dispose();
      platform.dispose();
    });

    test('play before init throws', () async {
      expect(() => controller.play(), throwsStateError);
    });

    test('emits state updates from platform events', () async {
      await controller.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 1024, channels: 2));

      final states = <AudioState>[];
      final sub = controller.states.listen(states.add);

      platform.emitState(<String, Object?>{
        'type': 'state',
        'positionMs': 120,
        'durationMs': 1000,
        'isPlaying': true,
        'bufferedMs': 400,
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(states, isNotEmpty);
      final last = states.last;
      expect(last.position, const Duration(milliseconds: 120));
      expect(last.duration, const Duration(milliseconds: 1000));
      expect(last.isPlaying, isTrue);
      expect(last.bufferedPosition, const Duration(milliseconds: 400));

      await sub.cancel();
    });

    test('error events surface in state', () async {
      await controller.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 1024, channels: 2));
      final errors = controller.states.where((s) => s.error != null);

      platform.emitState(<String, Object?>{
        'type': 'error',
        'message': 'network error',
      });

      final first = await errors.first;
      expect(first.error, 'network error');
    });

    test('load failure clears buffering flag and surfaces error', () async {
      await controller.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 1024, channels: 2));
      platform.shouldThrow = true;

      await expectLater(controller.load('file://sample'), throwsStateError);
      expect(controller.state.isBuffering, isFalse);
      expect(controller.state.error, contains('load failed'));
    });

    test('exposes pcm/spectrum buffers and drains platform events by timestamp order', () async {
      await controller.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 1024, channels: 2));

      platform.emitPcm(<String, Object?>{
        'sequence': 1,
        'timestampMs': 10,
        'samples': <double>[0.1],
      });
      platform.emitPcm(<String, Object?>{
        'sequence': 2,
        'timestampMs': 5, // out-of-order, should be dropped.
        'samples': <double>[0.2],
      });
      platform.emitSpectrum(<String, Object?>{
        'sequence': 1,
        'timestampMs': 15,
        'bins': <double>[0.3, 0.4],
        'binHz': 50.0,
      });
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final pcmRes = controller.pcmBuffer.drain(10);
      expect(pcmRes.frames.map((f) => f.sequence), [1]);
      final specRes = controller.spectrumBuffer.drain(10);
      expect(specRes.frames.single.bins, [0.3, 0.4]);
    });
  });
}
