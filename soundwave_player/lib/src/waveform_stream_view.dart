import 'dart:async';

import 'package:flutter/material.dart';

import 'pcm_buffer.dart';
import 'waveform_cache.dart';
import 'waveform_view.dart';

/// 将 PCM Buffer 与 WaveformView 对接的便捷组件，内置刷新节流。
class WaveformStreamView extends StatefulWidget {
  const WaveformStreamView({
    super.key,
    required this.buffer,
    this.color = Colors.blue,
    this.background = Colors.black,
    this.maxSamples = 5000,
    this.frameInterval = const Duration(milliseconds: 16),
    this.maxFramesPerTick = 8,
    this.strokeWidth = 1.0,
    this.height = 120,
    this.onDrain,
  });

  final PcmBuffer buffer;
  final Color color;
  final Color background;
  final int maxSamples;
  final Duration frameInterval;
  final int maxFramesPerTick;
  final double strokeWidth;
  final double height;
  final void Function(PcmPullResult result)? onDrain;

  @override
  State<WaveformStreamView> createState() => _WaveformStreamViewState();
}

class _WaveformStreamViewState extends State<WaveformStreamView> {
  late WaveformCache _cache;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cache = WaveformCache(maxSamples: widget.maxSamples);
    _timer = Timer.periodic(widget.frameInterval, (_) {
      final res = widget.buffer.drain(widget.maxFramesPerTick); // 一次读取有限帧，避免过载。
      if (res.frames.isNotEmpty || res.droppedBefore > 0) {
        widget.onDrain?.call(res);
        setState(() {
          for (final f in res.frames) {
            _cache.addSamples(f.samples);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: WaveformView(
        frames: const [],
        cache: _cache,
        color: widget.color,
        background: widget.background,
        strokeWidth: widget.strokeWidth,
      ),
    );
  }
}
