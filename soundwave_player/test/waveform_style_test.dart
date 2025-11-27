import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

void main() {
  test('WaveformStyle overrides defaults in WaveformView', () {
    const style = WaveformStyle(
      color: Colors.red,
      background: Colors.white,
      strokeWidth: 2.0,
    );
    final view = WaveformView(
      frames: const [],
      style: style,
      color: Colors.blue, // should be overridden
      background: Colors.black,
      strokeWidth: 1.0,
    );

    expect(view.color, style.color);
    expect(view.background, style.background);
    expect(view.strokeWidth, style.strokeWidth);
  });
}
