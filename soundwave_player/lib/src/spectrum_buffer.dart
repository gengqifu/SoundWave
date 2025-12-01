import 'dart:async';

import 'spectrum_frame.dart';
import 'spectrum_queue.dart';

class SpectrumPullResult {
  const SpectrumPullResult(this.frames, {this.droppedBefore = 0});

  final List<SpectrumFrame> frames;
  final int droppedBefore;
}

/// 频谱事件缓冲：订阅 Spectrum 流，过滤非法/乱序数据，支持限量读取。
class SpectrumBuffer {
  SpectrumBuffer({required Stream<dynamic> stream, int maxFrames = 30})
      : _queue = SpectrumQueue(maxFrames: maxFrames) {
    _subscription = stream.listen(_handleEvent);
  }

  final SpectrumQueue _queue;
  late final StreamSubscription<dynamic> _subscription;
  int _droppedFromStream = 0;
  int _lastTimestampMs = -1;

  void _handleEvent(dynamic event) {
    if (event is! Map) return;
    final droppedBefore = (event['droppedBefore'] as num?)?.toInt() ?? 0;
    final dropped = (event['dropped'] as bool?) ?? false;
    if (dropped) {
      _droppedFromStream += droppedBefore > 0 ? droppedBefore : 1;
      return;
    }
    final seq = (event['sequence'] as num?)?.toInt();
    final ts = (event['timestampMs'] as num?)?.toInt();
    final binsRaw = event['bins'];
    final binHz = (event['binHz'] as num?)?.toDouble() ?? 0;
    if (seq == null || ts == null || binsRaw is! List) {
      return;
    }
    if (ts < _lastTimestampMs) {
      // 认为是 seek/重置，清空队列并接受新时间基。
      _queue.clear();
      _droppedFromStream = 0;
      _lastTimestampMs = ts;
    } else {
      _lastTimestampMs = ts;
    }
    final bins = binsRaw.whereType<num>().map((n) => n.toDouble()).toList(growable: false);
    _droppedFromStream += droppedBefore;
    _queue.push(SpectrumFrame(sequence: seq, timestampMs: ts, bins: bins, binHz: binHz));
  }

  SpectrumPullResult drain(int maxCount) {
    final res = _queue.take(maxCount);
    final totalDropped = res.droppedBefore + _droppedFromStream;
    _droppedFromStream = 0;
    return SpectrumPullResult(res.frames, droppedBefore: totalDropped);
  }

  void reset() {
    _queue.clear();
    _droppedFromStream = 0;
    _lastTimestampMs = -1;
  }

  int get length => _queue.length;

  void dispose() {
    _subscription.cancel();
    reset();
  }
}
