import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

import 'helpers/fake_soundwave_player.dart';

void main() {
  const skipStreaming = true;

  group('Streaming perf smoke', () {
    late FakePlatform platform;
    late AudioController controller;

    setUp(() async {
      platform = FakePlatform();
      controller = AudioController(platform: platform);
      await controller.init(const SoundwaveConfig(
          sampleRate: 48000, bufferSize: 1024, channels: 2));
      await controller.load('https://example.com/stream.aac');
    });

    tearDown(() {
      controller.dispose();
      platform.dispose();
    });

    test('handles pcm+spectrum burst without crashing', () async {
      // Simulate a burst of PCM + spectrum frames as in weak network jitter recovery.
      for (int i = 0; i < 200; i++) {
        platform.emitPcm(<String, Object?>{
          'sequence': i,
          'timestampMs': i * 10,
          'samples': <double>[0.1, -0.1],
        });
        if (i.isEven) {
          platform.emitSpectrum(<String, Object?>{
            'sequence': i,
            'timestampMs': i * 10,
            'bins': <double>[0.2, 0.3],
            'binHz': 50.0,
          });
        }
      }

      // Allow buffers to receive events.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final pcmRes = controller.pcmBuffer.drain(300);
      final specRes = controller.spectrumBuffer.drain(300);

      expect(pcmRes.frames, isNotEmpty);
      expect(specRes.frames, isNotEmpty);
    }, skip: skipStreaming);
  });
}
