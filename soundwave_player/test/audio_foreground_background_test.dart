import 'dart:async';

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
  });
}
