import 'dart:math' as math;

import 'package:flutter/material.dart';

class SpectrumBin {
  const SpectrumBin({required this.frequency, required this.magnitude});
  final double frequency;
  final double magnitude;
}

class SpectrumStyle {
  const SpectrumStyle({
    this.barColor = Colors.cyan,
    this.background = Colors.black,
    this.barWidth = 2.0,
    this.spacing = 1.0,
    this.logScale = false,
  });

  final Color barColor;
  final Color background;
  final double barWidth;
  final double spacing;
  final bool logScale;
}

class SpectrumView extends StatelessWidget {
  const SpectrumView({
    super.key,
    required this.bins,
    this.style = const SpectrumStyle(),
  });

  final List<SpectrumBin> bins;
  final SpectrumStyle style;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SpectrumPainter(bins, style),
      size: const Size(double.infinity, 140),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter(this.bins, this.style);

  final List<SpectrumBin> bins;
  final SpectrumStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = style.background;
    canvas.drawRect(Offset.zero & size, bgPaint);
    if (bins.isEmpty) return;

    double maxMag = 0;
    for (final b in bins) {
      final m = b.magnitude.abs();
      if (m > maxMag) maxMag = m;
    }
    if (maxMag <= 0) return;

    final paint = Paint()
      ..color = style.barColor
      ..style = PaintingStyle.fill;

    final double totalWidth = size.width;
    final double barFullWidth = style.barWidth + style.spacing;
    final int maxBars = (totalWidth / barFullWidth).floor().clamp(1, bins.length);
    final step = bins.length / maxBars;

    for (int i = 0; i < maxBars; i++) {
      final bin = bins[(i * step).floor()];
      final magnitudeRaw = style.logScale ? (bin.magnitude > 0 ? log10(bin.magnitude) : 0) : bin.magnitude;
      final normalized = (magnitudeRaw / maxMag).clamp(0.0, 1.0);
      final barHeight = normalized * size.height;
      final left = i * barFullWidth;
      final rect = Rect.fromLTWH(left, size.height - barHeight, style.barWidth, barHeight);
      canvas.drawRect(rect, paint);
    }
  }

  double log10(double x) => x <= 0 ? 0 : (math.log(x) / math.ln10);

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    return oldDelegate.bins != bins || oldDelegate.style != style;
  }
}
