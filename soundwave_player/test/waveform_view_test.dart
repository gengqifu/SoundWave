import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WaveformView', () {
    testWidgets('renders min/max buckets for samples', (WidgetTester tester) async {
      // 构造简单正弦/方波混合。
      final samples = <double>[];
      for (int i = 0; i < 200; i++) {
        samples.add(i.isEven ? 1.0 : -1.0);
      }
      final frame = PcmFrame(sequence: 1, timestampMs: 0, samples: samples);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: WaveformView(
                frames: [frame],
                color: Colors.green,
                background: Colors.black,
              ),
            ),
          ),
        ),
      ));

      await expectLater(
        find.byType(WaveformView),
        matchesGoldenFile('waveform_view_golden.png'),
      );
    });
  });
}
