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
          throw PlatformException(code: 'native_error', message: 'boom', details: {'code': 500});
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
      await player.init(const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2));

      expect(calls, hasLength(1));
      final call = calls.first;
      expect(call.method, 'init');
      expect(
        call.arguments,
        <String, Object?>{'sampleRate': 48000, 'bufferSize': 2048, 'channels': 2},
      );
    });

    test('init twice throws', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2));
      expect(
        () => player.init(const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2)),
        throwsStateError,
      );
    });

    test('load rejects empty source', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2));
      expect(() => player.load(' '), throwsArgumentError);
    });

    test('load before init throws', () async {
      final player = SoundwavePlayer();
      expect(() => player.load('file://sample'), throwsStateError);
    });

    test('seek rejects negative position', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2));
      expect(() => player.seek(const Duration(milliseconds: -1)), throwsArgumentError);
    });

    test('play before init throws', () async {
      final player = SoundwavePlayer();
      expect(() => player.play(), throwsStateError);
    });

    test('play maps platform errors to domain exception', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2));
      expect(
        () => player.play(),
        throwsA(isA<SoundwaveException>()
            .having((e) => e.code, 'code', 'native_error')
            .having((e) => e.message, 'message', 'boom')
            .having((e) => e.details, 'details', containsPair('code', 500))),
      );
    });

    test('load forwards args', () async {
      final player = SoundwavePlayer();
      await player.init(const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2));
      await player.load('file://sample', headers: {'token': 'abc'});
      expect(calls.last.method, 'load');
      expect(
        calls.last.arguments,
        <String, Object?>{
          'source': 'file://sample',
          'headers': <String, Object?>{'token': 'abc'},
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
