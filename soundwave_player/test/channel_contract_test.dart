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
