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
    this.freqLogScale = true,
  });

  final Color barColor;
  final Color background;
  final double barWidth;
  final double spacing;
  final bool logScale;
  final bool freqLogScale;
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

    // 预处理幅度：对数压缩再归一化，避免单个峰值淹没整体。
    final processed = <double>[];
    double maxMag = 0;
    for (final b in bins) {
      double m = b.magnitude.abs();
      m = style.logScale ? (m > 0 ? log10(m) : 0) : math.log(m + 1); // log 压缩动态范围
      processed.add(m);
      if (m > maxMag) maxMag = m;
    }
    if (maxMag <= 0) return;

    final paint = Paint()
      ..color = style.barColor
      ..style = PaintingStyle.fill;

    final double totalWidth = size.width;
    if (totalWidth <= 0) return;

    // 让柱子横向铺满：barWidth/spacing 作为偏好，但不足的情况下按等距拉伸。
    final double preferredFull = style.barWidth + style.spacing;
    final int maxBars = math.max(
      1,
      math.min(bins.length, preferredFull > 0 ? (totalWidth / preferredFull).floor() : bins.length),
    );
    final double xStep = totalWidth / maxBars;
    final double barWidth = math.max(
      0.5, // 避免宽度过小不可见
      math.min(style.barWidth, xStep - style.spacing),
    );

    // 频率轴可选 log 分布，将低频更平均铺开到全宽，避免只挤在左侧。
    final double binHz;
    if (bins.length >= 2) {
      binHz = (bins[1].frequency - bins[0].frequency).abs();
    } else {
      binHz = bins.isNotEmpty ? math.max(1e-9, bins.first.frequency) : 1.0;
    }
    final double minFreq = math.max(binHz, bins.isNotEmpty ? bins.first.frequency : binHz);
    final double maxFreq = bins.isNotEmpty ? bins.last.frequency + binHz : binHz;

    for (int i = 0; i < maxBars; i++) {
      final double t = maxBars == 1 ? 0.0 : i / (maxBars - 1);
      double sampleIdx;
      if (style.freqLogScale && maxFreq > minFreq) {
        // log 均分频率
        final double targetFreq =
            minFreq * math.pow(maxFreq / minFreq, t); // start->end 按 log 平滑放大低频
        sampleIdx = targetFreq / math.max(1e-9, binHz);
      } else {
        sampleIdx = t * (bins.length - 1);
      }

      final int idx0 = sampleIdx.floor().clamp(0, bins.length - 1);
      final int idx1 = sampleIdx.ceil().clamp(0, bins.length - 1);
      final double frac = sampleIdx - idx0;
      final double magnitudeRaw =
          processed[idx0] * (1 - frac) + processed[idx1] * frac; // 线性插值，避免锯齿
      final normalized = (magnitudeRaw / maxMag).clamp(0.0, 1.0);
      final barHeight = normalized * size.height;
      if (barHeight <= 0) continue;
      final left = i * xStep + (xStep - barWidth) * 0.5;
      final rect = Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight);
      canvas.drawRect(rect, paint);
    }
  }

  double log10(double x) => x <= 0 ? 0 : (math.log(x) / math.ln10);

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    return oldDelegate.bins != bins || oldDelegate.style != style;
  }
}
