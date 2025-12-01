import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

import 'helpers/fake_soundwave_player.dart';

void main() {
  group('AudioController foreground/background (TDD)', () {
    late FakePlatform platform;
    late AudioController controller;

    setUp(() async {
      platform = FakePlatform();
      controller = AudioController(platform: platform);
      await controller.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 1024, channels: 2));
      await controller.load('file:///tmp/sample.mp3');
      await controller.play();
    });

    tearDown(() {
      controller.dispose();
      platform.dispose();
    });

    test('losing audio focus pauses playback and reports buffering', () async {
      platform.emitState(<String, Object?>{
        'type': 'focusLost',
        'message': 'A2DP device connected',
      });

      final state = await controller.states
          .firstWhere((s) => s.isPlaying == false && s.isBuffering == true)
          .timeout(const Duration(milliseconds: 200));
      expect(state.error, isNotNull);
    });

    test('regaining focus resumes playback and redraws', () async {
      platform.emitState(<String, Object?>{
        'type': 'resumedFromBackground',
        'positionMs': 5000,
        'bufferedMs': 7000,
      });

      final state = await controller.states
          .firstWhere(
              (s) => s.isPlaying == true && s.position.inMilliseconds >= 5000)
          .timeout(const Duration(milliseconds: 200));
      expect(state.bufferedPosition?.inMilliseconds ?? 0, greaterThanOrEqualTo(7000));
    });

    test('background/resume does not break pcm pipeline', () async {
      platform.emitPcm(<String, Object?>{
        'sequence': 1,
        'timestampMs': 0,
        'samples': <double>[0.1, -0.1],
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.pcmBuffer.drain(5).frames, isNotEmpty);

      platform.emitState(<String, Object?>{'type': 'focusLost', 'message': 'call incoming'});
      platform.emitPcm(<String, Object?>{
        'sequence': 2,
        'timestampMs': 10,
        'samples': <double>[0.2, -0.2],
      });
      platform.emitState(<String, Object?>{
        'type': 'resumedFromBackground',
        'positionMs': 20,
        'bufferedMs': 30,
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final framesAfter = controller.pcmBuffer.drain(5).frames;
      expect(framesAfter.map((f) => f.sequence), contains(2));
    });
  });
}
