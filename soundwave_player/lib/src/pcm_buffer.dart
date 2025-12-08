import 'dart:async';

import 'pcm_frame.dart';
import 'pcm_queue.dart';

class PcmPullResult {
  const PcmPullResult(this.frames, {this.droppedBefore = 0});

  final List<PcmFrame> frames;
  final int droppedBefore;
}

/// PCM 事件缓冲/背压：订阅 PCM 流，排队到达的帧，支持限量读取并合并丢弃计数。
class PcmBuffer {
  PcmBuffer({required Stream<dynamic> stream, int maxFrames = 30})
      : _queue = PcmQueue(maxFrames: maxFrames) {
    _subscription = stream.listen(_handleEvent);
  }

  final PcmQueue _queue;
  late final StreamSubscription<dynamic> _subscription;
  int _droppedFromStream = 0;
  int _lastTimestampMs = -1;
  int _version = 0;
  bool _paused = false;
  bool _muted = false;

  void _handleEvent(dynamic event) {
    if (_muted) return;
    if (event is! Map) return;
    final droppedBefore = (event['droppedBefore'] as num?)?.toInt() ?? 0;
    final dropped = (event['dropped'] as bool?) ?? false;
    if (dropped) {
      // 直接累计丢弃计数。
      _droppedFromStream += droppedBefore > 0 ? droppedBefore : 1;
      return;
    }
    final seq = (event['sequence'] as num?)?.toInt();
    final ts = (event['timestampMs'] as num?)?.toInt();
    final samplesRaw = event['samples'];
    if (seq == null || ts == null || samplesRaw is! List) {
      return;
    }
    if (ts < _lastTimestampMs) {
      // 认为是 seek/重置，清空队列与计数并接受新时间基。
      _queue.clear();
      _droppedFromStream = 0;
      _lastTimestampMs = ts;
      _version++;
    } else {
      _lastTimestampMs = ts;
    }
    final samples = samplesRaw.whereType<num>().map((n) => n.toDouble()).toList(growable: false);
    _droppedFromStream += droppedBefore;
    _queue.push(PcmFrame(sequence: seq, timestampMs: ts, samples: samples));
  }

  /// 限量取出帧，并合并流侧与队列侧的丢弃计数。
  PcmPullResult drain(int maxCount) {
    if (_paused) {
      return const PcmPullResult(<PcmFrame>[], droppedBefore: 0);
    }
    final res = _queue.take(maxCount);
    final totalDropped = res.droppedBefore + _droppedFromStream;
    _droppedFromStream = 0;
    return PcmPullResult(res.frames, droppedBefore: totalDropped);
  }

  void pause() {
    _paused = true;
    reset();
  }

  void resume() {
    _paused = false;
  }

  void mute() {
    _muted = true;
    reset();
  }

  void unmute() {
    _muted = false;
  }

  bool get paused => _paused;

  void reset() {
    _queue.clear();
    _droppedFromStream = 0;
    _lastTimestampMs = -1;
    _version++;
  }

  int get length => _queue.length;
  int get version => _version;

  void dispose() {
    _subscription.cancel();
    reset();
  }
}
