import 'package:flutter/material.dart';

class WaveformStyle {
  const WaveformStyle({
    this.color = Colors.blue,
    this.background = Colors.black,
    this.strokeWidth = 1.0,
  });

  final Color color;
  final Color background;
  final double strokeWidth;
}
