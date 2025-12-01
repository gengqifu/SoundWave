import 'dart:collection';

import 'spectrum_frame.dart';

class SpectrumDequeueResult {
  const SpectrumDequeueResult(this.frames, {this.droppedBefore = 0});

  final List<SpectrumFrame> frames;
  final int droppedBefore;
}

/// 频谱帧队列，按到达顺序 FIFO，超出容量丢弃最旧帧并累计 dropped。
class SpectrumQueue {
  SpectrumQueue({this.maxFrames = 30}) : assert(maxFrames > 0);

  final int maxFrames;
  final ListQueue<SpectrumFrame> _queue = ListQueue<SpectrumFrame>();
  int _dropped = 0;

  void push(SpectrumFrame frame) {
    _queue.addLast(frame);
    if (_queue.length > maxFrames) {
      _queue.removeFirst();
      _dropped++;
    }
  }

  SpectrumDequeueResult take(int maxCount) {
    if (maxCount <= 0) {
      return SpectrumDequeueResult(const <SpectrumFrame>[], droppedBefore: _dropped);
    }
    final count = maxCount > _queue.length ? _queue.length : maxCount;
    final frames = <SpectrumFrame>[];
    for (int i = 0; i < count; ++i) {
      frames.add(_queue.removeFirst());
    }
    final droppedBefore = _dropped;
    _dropped = 0;
    return SpectrumDequeueResult(frames, droppedBefore: droppedBefore);
  }

  int get length => _queue.length;
  int get dropped => _dropped;

  void clear() {
    _queue.clear();
    _dropped = 0;
  }
}
