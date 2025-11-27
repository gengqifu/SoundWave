import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EventChannel stress', () {
    const pcmChannel = EventChannel('soundwave_player/events/pcm');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(pcmChannel, _BurstStreamHandler());
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(pcmChannel, null);
    });

    test('pcm stream handles high frequency burst', () async {
      final player = SoundwavePlayer();
      final stream = player.pcmEvents.take(5000);

      final count = await stream.length.timeout(const Duration(seconds: 2));
      expect(count, 5000);
    });
  });
}

class _BurstStreamHandler extends MockStreamHandler {
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    const total = 5000;
    for (int i = 0; i < total; i++) {
      events.success(<String, Object?>{
        'sequence': i,
        'timestampMs': i,
        'samples': <double>[0.0, 0.0],
      });
    }
    events.endOfStream();
  }

  @override
  void onCancel(Object? arguments) {
    // no-op
  }
}
