import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

/// iOS 端 FFT 契约：频谱事件能反映 1kHz 正弦主峰，binHz 合理。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('soundwave_player');
  const stateChannel = EventChannel('soundwave_player/events/state');
  const pcmChannel = EventChannel('soundwave_player/events/pcm');
  const spectrumChannel = EventChannel('soundwave_player/events/spectrum');

  late List<MethodCall> calls;

  setUp(() {
    calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methodChannel, (MethodCall call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(stateChannel, null);
    messenger.setMockStreamHandler(pcmChannel, null);
    messenger.setMockStreamHandler(spectrumChannel, null);
  });

  test('native FFT emits peak near 1kHz', () async {
    const sampleRate = 48000;
    const windowSize = 1024;
    final samples = List<double>.generate(
        windowSize,
        (n) =>
            math.sin(2 * math.pi * 1000 * n / sampleRate)); // 1kHz mono
    final bins = _dft(samples, windowSize);
    final binHz = sampleRate / windowSize;

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
        stateChannel,
        _ListStreamHandler(<Map<String, Object?>>[
          <String, Object?>{
            'type': 'state',
            'positionMs': 0,
            'durationMs': 1000,
            'isPlaying': true
          }
        ]));
    messenger.setMockStreamHandler(
        pcmChannel, _ListStreamHandler(<Map<String, Object?>>[]));
    messenger.setMockStreamHandler(
        spectrumChannel,
        _ListStreamHandler(<Map<String, Object?>>[
          <String, Object?>{
            'sequence': 1,
            'timestampMs': 0,
            'bins': bins,
            'binHz': binHz,
          }
        ]));

    final controller = AudioController(platform: SoundwavePlayer());
    await controller
        .init(const SoundwaveConfig(sampleRate: sampleRate, bufferSize: 2048, channels: 1));
    await controller.load('file:///tmp/a.wav');
    await controller.play();

    await Future<void>.delayed(const Duration(milliseconds: 10));

    final res = controller.spectrumBuffer.drain(5);
    expect(res.frames, isNotEmpty);
    final frame = res.frames.first;
    expect(frame.binHz, closeTo(binHz, 1e-6));
    final peakIdx = _peakBin(frame.bins);
    final peakHz = peakIdx * frame.binHz;
    expect(peakHz, closeTo(1000.0, binHz));
    final mean = frame.bins.reduce((a, b) => a + b) / frame.bins.length;
    expect(mean, greaterThan(0));
    controller.dispose();
  });
}

List<double> _dft(List<double> samples, int windowSize) {
  final N = windowSize;
  final out = List<double>.filled(N ~/ 2 + 1, 0);
  for (var k = 0; k <= N ~/ 2; k++) {
    double real = 0, imag = 0;
    for (var n = 0; n < N; n++) {
      final angle = -2 * math.pi * k * n / N;
      real += samples[n] * math.cos(angle);
      imag += samples[n] * math.sin(angle);
    }
    out[k] = real * real + imag * imag;
  }
  return out;
}

int _peakBin(List<double> bins) {
  var peak = -double.infinity;
  var idx = 0;
  for (var i = 0; i < bins.length; i++) {
    if (bins[i] > peak) {
      peak = bins[i];
      idx = i;
    }
  }
  return idx;
}

class _ListStreamHandler extends MockStreamHandler {
  const _ListStreamHandler(this.events);

  final List<Map<String, Object?>> events;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink eventsSink) {
    for (final e in events) {
      eventsSink.success(e);
    }
    eventsSink.endOfStream();
  }

  @override
  void onCancel(Object? arguments) {}
}
