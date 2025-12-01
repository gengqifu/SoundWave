import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

import 'helpers/fake_soundwave_player.dart';

void main() {
  const skipStreaming = true;

  group('AudioController streaming integration (TDD)', () {
    late FakePlatform platform;
    late AudioController controller;

    setUp(() async {
      platform = FakePlatform();
      controller = AudioController(platform: platform);
      await controller.init(const SoundwaveConfig(
          sampleRate: 48000, bufferSize: 1024, channels: 2));
    });

    tearDown(() {
      controller.dispose();
      platform.dispose();
    });

    test('buffering event updates buffered position and flag', () async {
      await controller.load('https://example.com/stream.aac');

      platform.emitState(<String, Object?>{
        'type': 'buffering',
        'bufferedMs': 800,
        'isBuffering': true,
      });

      final state = await controller.states
          .firstWhere((s) => s.isBuffering && (s.bufferedPosition?.inMilliseconds ?? 0) >= 800)
          .timeout(const Duration(milliseconds: 200));
      expect(state.bufferedPosition, const Duration(milliseconds: 800));
    }, skip: skipStreaming);

    test('retry/timeout event surfaces message but keeps controller alive', () async {
      await controller.load('https://example.com/stream.aac');

      platform.emitState(<String, Object?>{
        'type': 'retry',
        'message': 'timeout',
        'attempt': 1,
      });

      final state = await controller.states
          .firstWhere((s) => (s.error ?? '').contains('timeout'))
          .timeout(const Duration(milliseconds: 200));
      expect(state.isBuffering, isTrue);

      // Controller should remain usable after retry notification.
      await controller.play();
    }, skip: skipStreaming);

    test('404 or unsupported format surfaces error without crash', () async {
      platform.shouldThrow = true;
      platform.throwError = const SoundwaveException('http_404', 'Not Found', null);

      await expectLater(
          controller.load('https://example.com/missing.mp3'),
          throwsA(isA<SoundwaveException>().having((e) => e.code, 'code', 'http_404')));
      expect(controller.state.error, isNotNull);
    }, skip: skipStreaming);
  });
}
