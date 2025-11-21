import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundwavePlayer MethodChannel contract (TDD stub)', () {
    test('init validates config and forwards to platform', () async {
      final player = SoundwavePlayer();
      await expectLater(
        () => player.init(const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2)),
        throwsA(isA<UnimplementedError>()),
      );
    });

    test('load rejects empty source', () async {
      final player = SoundwavePlayer();
      expect(() => player.load(' '), throwsA(anything));
    });

    test('seek rejects negative position', () async {
      final player = SoundwavePlayer();
      expect(() => player.seek(const Duration(milliseconds: -1)), throwsA(anything));
    });

    test('play maps platform errors to domain exception (to be implemented)', () async {
      final player = SoundwavePlayer();
      await expectLater(() => player.play(), throwsA(anything));
    });
  });

  group('SoundwavePlayer EventChannel contract (placeholder)', () {
    test('streams should be broadcast when implemented', () {
      // TODO: once EventChannels are added, assert isBroadcast.
    });
  });
}
