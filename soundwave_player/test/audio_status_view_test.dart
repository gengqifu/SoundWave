import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

import 'helpers/fake_soundwave_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioStatusView', () {
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

    testWidgets('renders state stream updates', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AudioStatusView(controller: controller),
        ),
      ));

      Text status() => tester.widget<Text>(find.byKey(const Key('status_text')));
      Text position() => tester.widget<Text>(find.byKey(const Key('position_text')));
      Text buffered() => tester.widget<Text>(find.byKey(const Key('buffer_text')));

      expect(status().data, 'Status: Paused');
      expect(position().data, 'Position: 00:00 / 00:00');
      expect(buffered().data, 'Buffered: 00:00');

      platform.emitState(<String, Object?>{
        'type': 'state',
        'positionMs': 1500,
        'durationMs': 4000,
        'bufferedMs': 2500,
        'isPlaying': true,
      });
      await tester.runAsync(
          () => controller.states.firstWhere((s) => s.isPlaying));
      await tester.pump(const Duration(milliseconds: 20));

      expect(controller.state.isPlaying, isTrue);
      expect(status().data, 'Status: Playing');
      expect(position().data, 'Position: 00:01 / 00:04');
      expect(buffered().data, 'Buffered: 00:02');

      platform.emitState(<String, Object?>{
        'type': 'error',
        'message': 'network down',
      });
      await tester.runAsync(
          () => controller.states.firstWhere((s) => s.error != null));
      await tester.pumpAndSettle();

      expect(status().data, 'Status: Error: network down');
    });
  });
}
