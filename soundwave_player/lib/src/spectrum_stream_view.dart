import 'dart:async';

import 'package:flutter/material.dart';

import 'spectrum_buffer.dart';
import 'spectrum_frame.dart';
import 'spectrum_view.dart';

/// 将 SpectrumBuffer 对接到 SpectrumView，按音频时间戳顺序刷新。
class SpectrumStreamView extends StatefulWidget {
  const SpectrumStreamView({
    super.key,
    required this.buffer,
    this.style = const SpectrumStyle(),
    this.frameInterval = const Duration(milliseconds: 33),
    this.maxFramesPerTick = 2,
    this.onDrain,
  });

  final SpectrumBuffer buffer;
  final SpectrumStyle style;
  final Duration frameInterval;
  final int maxFramesPerTick;
  final void Function(SpectrumPullResult result)? onDrain;

  @override
  State<SpectrumStreamView> createState() => _SpectrumStreamViewState();
}

class _SpectrumStreamViewState extends State<SpectrumStreamView> {
  Timer? _timer;
  List<SpectrumBin> _bins = const [];
  int _lastTimestampMs = -1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.frameInterval, (_) {
      final res = widget.buffer.drain(widget.maxFramesPerTick);
      if (res.frames.isNotEmpty || res.droppedBefore > 0) {
        widget.onDrain?.call(res);
        if (res.frames.isNotEmpty) {
          // 取最后一帧，保持与音频时间基同步。
          final last = res.frames.last;
          if (last.timestampMs < _lastTimestampMs) {
            return;
          }
          setState(() {
            _bins = _toBins(last);
            _lastTimestampMs = last.timestampMs;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(covariant SpectrumStreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.buffer.length < oldWidget.buffer.length) {
      _bins = const [];
      _lastTimestampMs = -1;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<SpectrumBin> _toBins(SpectrumFrame frame) {
    final List<SpectrumBin> out = [];
    final double binHz = frame.binHz;
    for (int i = 0; i < frame.bins.length; ++i) {
      out.add(SpectrumBin(
        frequency: binHz > 0 ? i * binHz : i.toDouble(),
        magnitude: frame.bins[i],
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return SpectrumView(
      bins: _bins,
      style: widget.style,
    );
  }
}
