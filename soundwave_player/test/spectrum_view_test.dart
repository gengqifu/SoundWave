import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpectrumView', () {
    testWidgets('renders bars with correct count and height order', (tester) async {
      final bins = <SpectrumBin>[
        const SpectrumBin(frequency: 100, magnitude: 0.2),
        const SpectrumBin(frequency: 200, magnitude: 0.8),
        const SpectrumBin(frequency: 300, magnitude: 0.5),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 60,
            height: 100,
            child: SpectrumView(
              bins: bins,
              style: const SpectrumStyle(barWidth: 10, spacing: 0, barColor: Colors.red),
            ),
          ),
        ),
      ));

      await expectLater(
        find.byType(SpectrumView),
        matchesGoldenFile('spectrum_view_golden.png'),
      );
    });
  });
}
