import 'dart:collection';
import 'dart:math';

class WaveformBucket {
  const WaveformBucket(this.min, this.max);
  final double min;
  final double max;
}

/// 简易波形缓存：保留固定样本窗口，按像素宽度抽稀为 min/max buckets。
class WaveformCache {
  WaveformCache({this.maxSamples = 5000}) : assert(maxSamples > 0);

  final int maxSamples;
  final ListQueue<double> _samples = ListQueue<double>();
  int _version = 0;

  int get version => _version;

  void addSamples(Iterable<double> samples) {
    var mutated = false;
    for (final s in samples) {
      _samples.add(s);
      mutated = true;
    }
    while (_samples.length > maxSamples) {
      _samples.removeFirst();
      mutated = true;
    }
    if (mutated) {
      _version++;
    }
  }

  List<WaveformBucket> bucketsForWidth(double width) {
    if (_samples.isEmpty || width <= 0) return const <WaveformBucket>[];
    final int bucketCount = max(1, width.ceil());
    final int bucketSize = max(1, (_samples.length / bucketCount).ceil());
    final List<WaveformBucket> buckets = [];
    final samplesList = _samples.toList(growable: false);
    for (int i = 0; i < samplesList.length; i += bucketSize) {
      final end = min(i + bucketSize, samplesList.length);
      double minV = 1.0;
      double maxV = -1.0;
      for (int j = i; j < end; j++) {
        final v = samplesList[j].clamp(-1.0, 1.0);
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
      buckets.add(WaveformBucket(minV, maxV));
    }
    return buckets;
  }

  int get length => _samples.length;

  void clear() {
    if (_samples.isEmpty) return;
    _samples.clear();
    _version++;
  }
}
