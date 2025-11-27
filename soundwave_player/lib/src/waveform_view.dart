import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pcm_frame.dart';
import 'waveform_cache.dart';
import 'waveform_style.dart';

class WaveformView extends StatelessWidget {
  WaveformView(
      {super.key,
      required this.frames,
      this.style,
      Color color = Colors.blue,
      Color? background,
      this.cache,
      double strokeWidth = 1.0})
      : color = style?.color ?? color,
        background = style?.background ?? background ?? Colors.black,
        strokeWidth = style?.strokeWidth ?? strokeWidth;

  final List<PcmFrame> frames;
  final WaveformStyle? style;
  final Color color;
  final Color background;
  final WaveformCache? cache;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    // 如果传入 cache，先合并帧写入缓存，绘制时从缓存抽稀。
    if (cache != null) {
      for (final f in frames) {
        cache!.addSamples(f.samples);
      }
    }

    return CustomPaint(
      painter: _WaveformPainter(frames,
          color: color,
          background: background,
          strokeWidth: strokeWidth,
          cache: cache),
      size: const Size(double.infinity, 120),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.frames,
      {required this.color,
      required this.background,
      required this.strokeWidth,
      this.cache});

  final List<PcmFrame> frames;
  final Color color;
  final Color background;
  final double strokeWidth;
  final WaveformCache? cache;

  @override
  void paint(Canvas canvas, Size size) {
    final paintBg = Paint()..color = background;
    canvas.drawRect(Offset.zero & size, paintBg);

    if (frames.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final height = size.height;
    final width = size.width;
    final buckets = _buildBuckets(width);
    if (buckets.isEmpty) return;

    for (int i = 0; i < buckets.length; i++) {
      final x = (i / buckets.length) * width;
      final yMin = height * (0.5 - buckets[i].min * 0.5);
      final yMax = height * (0.5 - buckets[i].max * 0.5);
      path.moveTo(x, yMin);
      path.lineTo(x, yMax);
    }
    canvas.drawPath(path, paint);
  }

  List<WaveformBucket> _buildBuckets(double width) {
    if (frames.isEmpty || width <= 0) return const [];
    final samples = <double>[];
    for (final f in frames) {
      samples.addAll(f.samples);
    }
    if (cache != null) {
      cache!.addSamples(samples);
      return cache!.bucketsForWidth(width);
    }
    if (samples.isEmpty) return const [];
    final bucketSize = math.max(1, (samples.length / width).ceil());
    final int buckets = (samples.length / bucketSize).ceil();
    final result = <WaveformBucket>[];
    for (int i = 0; i < buckets; i++) {
      final start = i * bucketSize;
      final end = math.min(start + bucketSize, samples.length);
      double minV = 1.0;
      double maxV = -1.0;
      for (int j = start; j < end; j++) {
        final v = samples[j].clamp(-1.0, 1.0);
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
      result.add(WaveformBucket(minV, maxV));
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.frames != frames || oldDelegate.color != color || oldDelegate.background != background;
  }
}
