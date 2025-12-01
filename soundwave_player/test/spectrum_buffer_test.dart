import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

void main() {
  group('SpectrumBuffer', () {
    late StreamController<Map<String, Object?>> controller;
    late SpectrumBuffer buffer;

    setUp(() {
      controller = StreamController<Map<String, Object?>>.broadcast();
      buffer = SpectrumBuffer(stream: controller.stream, maxFrames: 2);
    });

    tearDown(() {
      buffer.dispose();
      controller.close();
    });

    test('keeps FIFO and aggregates droppedBefore', () async {
      controller.add(<String, Object?>{
        'sequence': 1,
        'timestampMs': 0,
        'bins': <double>[0.1],
        'binHz': 10.0,
      });
      controller.add(<String, Object?>{
        'sequence': 2,
        'timestampMs': 5,
        'bins': <double>[0.2],
        'binHz': 10.0,
        'droppedBefore': 2,
      });
      await Future<void>.delayed(Duration.zero);

      final res = buffer.drain(5);
      expect(res.frames.map((f) => f.sequence).toList(), [1, 2]);
      expect(res.droppedBefore, 2);
    });

    test('drops out-of-order timestamps', () async {
      controller.add(<String, Object?>{
        'sequence': 1,
        'timestampMs': 10,
        'bins': <double>[0.3],
        'binHz': 20.0,
      });
      controller.add(<String, Object?>{
        'sequence': 2,
        'timestampMs': 5, // out-of-order
        'bins': <double>[0.4],
        'binHz': 20.0,
      });
      await Future<void>.delayed(Duration.zero);

      final res = buffer.drain(5);
      expect(res.frames.map((f) => f.sequence), [1]);
      expect(res.droppedBefore, 1);
    });
  });
}
