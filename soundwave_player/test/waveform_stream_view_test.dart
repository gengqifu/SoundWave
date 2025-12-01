import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WaveformStreamView', () {
    testWidgets('drains buffer on tick with throttle', (tester) async {
      final controller = StreamController<Map<String, Object?>>.broadcast();
      final buffer = PcmBuffer(stream: controller.stream, maxFrames: 10);
      int drainCount = 0;
      int totalFrames = 0;

      await tester.pumpWidget(MaterialApp(
        home: WaveformStreamView(
          buffer: buffer,
          frameInterval: const Duration(milliseconds: 16),
          maxFramesPerTick: 2,
          onDrain: (res) {
            drainCount++;
            totalFrames += res.frames.length;
          },
        ),
      ));

      controller.add(<String, Object?>{
        'sequence': 1,
        'timestampMs': 0,
        'samples': <double>[0.1, -0.1],
      });
      controller.add(<String, Object?>{
        'sequence': 2,
        'timestampMs': 10,
        'samples': <double>[0.2, -0.2],
      });
      controller.add(<String, Object?>{
        'sequence': 3,
        'timestampMs': 20,
        'samples': <double>[0.3, -0.3],
      });

      await tester.pump(const Duration(milliseconds: 20));

      expect(drainCount, greaterThanOrEqualTo(1));
      expect(totalFrames, lessThanOrEqualTo(2)); // maxFramesPerTick limit

      await tester.pump(const Duration(milliseconds: 20));
      expect(totalFrames, 3); // remaining frames drained on next tick

      buffer.dispose();
      controller.close();
    });

    testWidgets('resets when timestamps roll back (seek)', (tester) async {
      final controller = StreamController<Map<String, Object?>>.broadcast();
      final buffer = PcmBuffer(stream: controller.stream, maxFrames: 10);
      int drainedSamples = 0;

      await tester.pumpWidget(MaterialApp(
        home: WaveformStreamView(
          buffer: buffer,
          frameInterval: const Duration(milliseconds: 10),
          maxFramesPerTick: 5,
          onDrain: (res) {
            for (final f in res.frames) {
              drainedSamples += f.samples.length;
            }
          },
        ),
      ));

      controller.add(<String, Object?>{
        'sequence': 1,
        'timestampMs': 50,
        'samples': <double>[0.1, -0.1],
      });
      await tester.pump(const Duration(milliseconds: 15));
      expect(drainedSamples, 2);

      // Timestamp rolls back simulating seek; should still be accepted.
      controller.add(<String, Object?>{
        'sequence': 2,
        'timestampMs': 10,
        'samples': <double>[0.2, -0.2, 0.3],
      });
      await tester.pump(const Duration(milliseconds: 15));
      expect(drainedSamples, 5);

      buffer.dispose();
      controller.close();
    });
  });
}
