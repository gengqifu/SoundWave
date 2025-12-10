import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundwavePlayer MethodChannel contract', () {
    const channel = MethodChannel('soundwave_player');
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call);
        if (call.method == 'play') {
          throw PlatformException(
              code: 'native_error', message: 'boom', details: {'code': 500});
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('init validates config and forwards to platform', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(
          sampleRate: 48000,
          bufferSize: 2048,
          channels: 2,
          pcmMaxFps: 30,
          pcmFramesPerPush: 64,
          pcmMaxPending: 5,
          spectrumMaxFps: 20,
          spectrumMaxPending: 3,
          connectTimeoutMs: 3000,
          readTimeoutMs: 5000,
          enableRangeRequests: true,
          ringBufferMs: 300,
          enableSkiaTracing: true));

      expect(calls, hasLength(1));
      final call = calls.first;
      expect(call.method, 'init');
      expect(
        call.arguments,
        <String, Object?>{
          'sampleRate': 48000,
          'bufferSize': 2048,
          'channels': 2,
          'visualization': <String, Object?>{
            'pcmMaxFps': 30,
            'pcmFramesPerPush': 64,
            'pcmMaxPending': 5,
            'spectrumMaxFps': 20,
            'spectrumMaxPending': 3,
            'enableSkiaTracing': true,
          },
          'network': <String, Object?>{
            'connectTimeoutMs': 3000,
            'readTimeoutMs': 5000,
            'enableRangeRequests': true,
          },
          'playback': <String, Object?>{
            'ringBufferMs': 300,
          }
        },
      );
    });

    test('init twice throws', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(
          sampleRate: 48000, bufferSize: 2048, channels: 2));
      expect(
        () => player.init(const SoundwaveConfig(
            sampleRate: 48000, bufferSize: 2048, channels: 2)),
        throwsStateError,
      );
    });

    test('load rejects empty source', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(
          sampleRate: 48000, bufferSize: 2048, channels: 2));
      expect(() => player.load(' '), throwsArgumentError);
    });

    test('load before init throws', () async {
      final player = SoundwavePlayer();
      expect(() => player.load('file://sample'), throwsStateError);
    });

    test('seek rejects negative position', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(
          sampleRate: 48000, bufferSize: 2048, channels: 2));
      expect(() => player.seek(const Duration(milliseconds: -1)),
          throwsArgumentError);
    });

    test('play before init throws', () async {
      final player = SoundwavePlayer();
      expect(() => player.play(), throwsStateError);
    });

    test('play maps platform errors to domain exception', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(
          sampleRate: 48000, bufferSize: 2048, channels: 2));
      expect(
        () => player.play(),
        throwsA(isA<SoundwaveException>()
            .having((e) => e.code, 'code', 'native_error')
            .having((e) => e.message, 'message', 'boom')
            .having((e) => e.details, 'details', containsPair('code', 500))),
      );
    });

    test('load forwards args with headers and range', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(
          sampleRate: 48000, bufferSize: 2048, channels: 2));
      await player.load('https://example.com/sample.mp3',
          headers: {'token': 'abc'}, rangeStart: 100, rangeEnd: 200);
      expect(calls.last.method, 'load');
      expect(
        calls.last.arguments,
        <String, Object?>{
          'source': 'https://example.com/sample.mp3',
          'headers': <String, Object?>{'token': 'abc'},
          'range': <String, Object?>{'start': 100, 'end': 200},
        },
      );
    });

    test('pushPcmFrame validates and forwards to platform', () async {
      final player = SoundwavePlayer();
      await player.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2));
      const frame = PcmInputFrame(
          samples: <double>[0.1, -0.1, 0.2, -0.2],
          sampleRate: 48000,
          channels: 2,
          timestampMs: 123,
          sequence: 1);
      await player.pushPcmFrame(frame);
      final call = calls.last;
      expect(call.method, 'pushPcmFrame');
      expect(
          call.arguments,
          containsPair(
              'samples', <double>[0.1, -0.1, 0.2, -0.2]));
      expect(call.arguments, containsPair('sampleRate', 48000));
      expect(call.arguments, containsPair('channels', 2));
      expect(call.arguments, containsPair('timestampMs', 123));
      expect(call.arguments, containsPair('sequence', 1));
      expect(call.arguments, containsPair('frameSize', 2));
    });

    test('subscribe/unsubscribe calls platform', () async {
      final player = SoundwavePlayer();
      await player.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2));
      await player.subscribeWaveform();
      await player.subscribeSpectrum();
      await player.unsubscribeWaveform();
      await player.unsubscribeSpectrum();
      expect(
          calls.map((c) => c.method),
          containsAll(
              ['subscribeWaveform', 'subscribeSpectrum', 'unsubscribeWaveform', 'unsubscribeSpectrum']));
    });

    test('init default params stay backward compatible', () async {
      final player = SoundwavePlayer();
      await player
          .init(const SoundwaveConfig(sampleRate: 44100, bufferSize: 1024, channels: 1));
      expect(calls.single.method, 'init');
      expect(
          calls.single.arguments,
          equals(<String, Object?>{
            'sampleRate': 44100,
            'bufferSize': 1024,
            'channels': 1,
          }));
    });

    test('load with relative or file url keeps optional args absent', () async {
      final player = SoundwavePlayer();
      await player
          .init(const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2));

      await player.load('sample.mp3'); // relative path allowed
      expect(calls.last.method, 'load');
      expect(calls.last.arguments, equals(<String, Object?>{'source': 'sample.mp3'}));

      await player.load('file:///tmp/a.wav');
      expect(calls.last.arguments, equals(<String, Object?>{'source': 'file:///tmp/a.wav'}));
    });

    test('subscribe/unsubscribe before init throws', () {
      final player = SoundwavePlayer();
      expect(() => player.subscribeWaveform(), throwsStateError);
      expect(() => player.subscribeSpectrum(), throwsStateError);
      expect(() => player.unsubscribeWaveform(), throwsStateError);
      expect(() => player.unsubscribeSpectrum(), throwsStateError);
    });

    test('push/subscribe/unsubscribe propagate platform errors', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(
          sampleRate: 48000, bufferSize: 2048, channels: 2));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'pushPcmFrame') {
          throw PlatformException(code: 'push_error', message: 'push fail');
        }
        if (call.method == 'subscribeWaveform') {
          throw PlatformException(code: 'sub_error', message: 'sub fail');
        }
        if (call.method == 'unsubscribeSpectrum') {
          throw PlatformException(code: 'unsub_error', message: 'unsub fail');
        }
        return null;
      });

      const frame = PcmInputFrame(
          samples: <double>[0.1, -0.1, 0.2, -0.2],
          sampleRate: 48000,
          channels: 2,
          timestampMs: 0,
          sequence: 0);
      expect(() => player.pushPcmFrame(frame),
          throwsA(isA<SoundwaveException>().having((e) => e.code, 'code', 'push_error')));
      expect(() => player.subscribeWaveform(),
          throwsA(isA<SoundwaveException>().having((e) => e.code, 'code', 'sub_error')));
      expect(() => player.unsubscribeSpectrum(),
          throwsA(isA<SoundwaveException>().having((e) => e.code, 'code', 'unsub_error')));
    });

    test('maps platform error codes to friendly messages', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(
          sampleRate: 48000, bufferSize: 2048, channels: 2));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'play') {
          throw PlatformException(code: 'invalid_format', message: null);
        }
        if (call.method == 'pause') {
          throw PlatformException(code: 'buffer_overflow', message: null);
        }
        if (call.method == 'stop') {
          throw PlatformException(code: 'fft_error', message: 'native fft failed');
        }
        return null;
      });

      expect(
          () => player.play(),
          throwsA(isA<SoundwaveException>()
              .having((e) => e.code, 'code', 'invalid_format')
              .having((e) => e.message, 'message', contains('格式错误'))));
      expect(
          () => player.pause(),
          throwsA(isA<SoundwaveException>()
              .having((e) => e.code, 'code', 'buffer_overflow')
              .having((e) => e.message, 'message', contains('缓冲过载'))));
      expect(
          () => player.stop(),
          throwsA(isA<SoundwaveException>()
              .having((e) => e.code, 'code', 'fft_error')
              .having((e) => e.message, 'message', contains('native fft failed'))));
    });
  });

  group('SoundwavePlayer EventChannel contract', () {
    test('streams are broadcast', () {
      final player = SoundwavePlayer();
      expect(player.stateEvents.isBroadcast, isTrue);
      expect(player.pcmEvents.isBroadcast, isTrue);
      expect(player.spectrumEvents.isBroadcast, isTrue);
    });
  });
}
