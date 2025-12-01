import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

void main() {
  group('PcmBuffer', () {
    late StreamController<Map<String, Object?>> controller;
    late PcmBuffer buffer;

    setUp(() {
      controller = StreamController<Map<String, Object?>>.broadcast();
      buffer = PcmBuffer(stream: controller.stream, maxFrames: 2);
    });

    tearDown(() {
      buffer.dispose();
      controller.close();
    });

    test('preserves order and aggregates droppedBefore', () async {
      controller.add(<String, Object?>{
        'sequence': 1,
        'timestampMs': 0,
        'samples': <double>[0.1],
      });
      controller.add(<String, Object?>{
        'sequence': 2,
        'timestampMs': 5,
        'samples': <double>[0.2],
        'droppedBefore': 2,
      });
      await Future<void>.delayed(Duration.zero);

      final res = buffer.drain(5);
      expect(res.frames.map((f) => f.sequence).toList(), [1, 2]);
      expect(res.droppedBefore, 2);
      expect(buffer.length, 0);
    });

    test('handles dropped marker events', () async {
      controller.add(<String, Object?>{'dropped': true, 'droppedBefore': 3});
      controller.add(<String, Object?>{
        'sequence': 10,
        'timestampMs': 10,
        'samples': <double>[0.5],
      });
      await Future<void>.delayed(Duration.zero);

      final res = buffer.drain(1);
      expect(res.frames.single.sequence, 10);
      expect(res.droppedBefore, 3);
    });

    test('queue overflow drops oldest and reports', () async {
      buffer.dispose();
      buffer = PcmBuffer(stream: controller.stream, maxFrames: 2);

      controller.add(<String, Object?>{
        'sequence': 1,
        'timestampMs': 0,
        'samples': <double>[0.1],
      });
      controller.add(<String, Object?>{
        'sequence': 2,
        'timestampMs': 5,
        'samples': <double>[0.2],
      });
      controller.add(<String, Object?>{
        'sequence': 3,
        'timestampMs': 10,
        'samples': <double>[0.3],
      });
      await Future<void>.delayed(Duration.zero);

      final res = buffer.drain(5);
      expect(res.frames.map((f) => f.sequence).toList(), [2, 3]);
      expect(res.droppedBefore, 1); // one dropped due to overflow
    });

    test('drops out-of-order timestamps to avoid time drift', () async {
      controller.add(<String, Object?>{
        'sequence': 1,
        'timestampMs': 20,
        'samples': <double>[0.4],
      });
      controller.add(<String, Object?>{
        'sequence': 2,
        'timestampMs': 10, // out-of-order, should be dropped.
        'samples': <double>[0.5],
      });
      await Future<void>.delayed(Duration.zero);

      final res = buffer.drain(5);
      expect(res.frames.map((f) => f.sequence), [1]);
      expect(res.droppedBefore, 1);
    });
  });
}
