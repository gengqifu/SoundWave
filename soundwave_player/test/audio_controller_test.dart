import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

import 'helpers/fake_soundwave_player.dart';

void main() {
  group('AudioController', () {
    late FakePlatform platform;
    late AudioController controller;

    setUp(() {
      platform = FakePlatform();
      controller = AudioController(platform: platform);
    });

    tearDown(() {
      controller.dispose();
      platform.dispose();
    });

    test('play before init throws', () async {
      expect(() => controller.play(), throwsStateError);
    });

    test('emits state updates from platform events', () async {
      await controller.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 1024, channels: 2));

      final states = <AudioState>[];
      final sub = controller.states.listen(states.add);

      platform.emitState(<String, Object?>{
        'type': 'state',
        'positionMs': 120,
        'durationMs': 1000,
        'isPlaying': true,
        'bufferedMs': 400,
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(states, isNotEmpty);
      final last = states.last;
      expect(last.position, const Duration(milliseconds: 120));
      expect(last.duration, const Duration(milliseconds: 1000));
      expect(last.isPlaying, isTrue);
      expect(last.bufferedPosition, const Duration(milliseconds: 400));

      await sub.cancel();
    });

    test('error events surface in state', () async {
      await controller.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 1024, channels: 2));
      final errors = controller.states.where((s) => s.error != null);

      platform.emitState(<String, Object?>{
        'type': 'error',
        'message': 'network error',
      });

      final first = await errors.first;
      expect(first.error, 'network error');
    });

    test('load failure clears buffering flag and surfaces error', () async {
      await controller.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 1024, channels: 2));
      platform.shouldThrow = true;

      await expectLater(controller.load('file://sample'), throwsStateError);
      expect(controller.state.isBuffering, isFalse);
      expect(controller.state.error, contains('load failed'));
    });

    test('exposes pcm/spectrum buffers and drains platform events by timestamp order', () async {
      await controller.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 1024, channels: 2));

      platform.emitPcm(<String, Object?>{
        'sequence': 1,
        'timestampMs': 10,
        'samples': <double>[0.1],
      });
      platform.emitPcm(<String, Object?>{
        'sequence': 2,
        'timestampMs': 5, // out-of-order, should be dropped.
        'samples': <double>[0.2],
      });
      platform.emitSpectrum(<String, Object?>{
        'sequence': 1,
        'timestampMs': 15,
        'bins': <double>[0.3, 0.4],
        'binHz': 50.0,
      });
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final pcmRes = controller.pcmBuffer.drain(10);
      expect(pcmRes.frames.map((f) => f.sequence), [2]);
      final specRes = controller.spectrumBuffer.drain(10);
      expect(specRes.frames.single.bins, [0.3, 0.4]);
    });

    test('seek resets buffers to accept earlier timestamps', () async {
      await controller.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 1024, channels: 2));
      platform.emitPcm(<String, Object?>{
        'sequence': 1,
        'timestampMs': 100,
        'samples': <double>[0.1],
      });
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(controller.pcmBuffer.drain(10).frames, isNotEmpty);

      await controller.seek(const Duration(milliseconds: 10));
      platform.emitPcm(<String, Object?>{
        'sequence': 2,
        'timestampMs': 10, // earlier than previous, should be accepted after reset.
        'samples': <double>[0.2],
      });
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final res = controller.pcmBuffer.drain(10);
      expect(res.frames.map((f) => f.sequence), [2]);
    });

    test('control flow keeps pcm/spectrum sequence across play/pause/seek', () async {
      await controller.init(
          const SoundwaveConfig(sampleRate: 48000, bufferSize: 1024, channels: 2));
      await controller.load('file:///tmp/a.wav');
      await controller.play();

      // Initial burst
      platform.emitPcm(<String, Object?>{
        'sequence': 1,
        'timestampMs': 0,
        'samples': <double>[0.1],
      });
      platform.emitPcm(<String, Object?>{
        'sequence': 2,
        'timestampMs': 10,
        'samples': <double>[0.2],
      });
      platform.emitSpectrum(<String, Object?>{
        'sequence': 1,
        'timestampMs': 0,
        'bins': <double>[0.5],
        'binHz': 50.0,
      });
      platform.emitSpectrum(<String, Object?>{
        'sequence': 2,
        'timestampMs': 10,
        'bins': <double>[0.6],
        'binHz': 50.0,
      });
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final burst1Pcm = controller.pcmBuffer.drain(10);
      final burst1Spec = controller.spectrumBuffer.drain(10);
      expect(burst1Pcm.frames.map((f) => f.sequence), [1, 2]);
      expect(burst1Spec.frames.map((f) => f.sequence), [1, 2]);

      // Pause then continue receiving frames.
      await controller.pause();
      expect(controller.state.isPlaying, isFalse);
      platform.emitPcm(<String, Object?>{
        'sequence': 3,
        'timestampMs': 20,
        'samples': <double>[0.3],
      });
      platform.emitSpectrum(<String, Object?>{
        'sequence': 3,
        'timestampMs': 20,
        'bins': <double>[0.7],
        'binHz': 50.0,
      });
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final burst2Pcm = controller.pcmBuffer.drain(10);
      final burst2Spec = controller.spectrumBuffer.drain(10);
      expect(burst2Pcm.frames.map((f) => f.sequence), [3]);
      expect(burst2Spec.frames.map((f) => f.sequence), [3]);

      // Seek should reset buffers and accept rolled-back timestamps.
      final prevVersion = controller.pcmBuffer.version;
      await controller.seek(const Duration(milliseconds: 5));
      platform.emitPcm(<String, Object?>{
        'sequence': 4,
        'timestampMs': 5,
        'samples': <double>[0.4],
      });
      platform.emitPcm(<String, Object?>{
        'sequence': 5,
        'timestampMs': 15,
        'samples': <double>[0.5],
      });
      platform.emitSpectrum(<String, Object?>{
        'sequence': 4,
        'timestampMs': 5,
        'bins': <double>[0.8],
        'binHz': 50.0,
      });
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final burst3Pcm = controller.pcmBuffer.drain(10);
      final burst3Spec = controller.spectrumBuffer.drain(10);
      expect(controller.pcmBuffer.version, greaterThan(prevVersion));
      expect(burst3Pcm.frames.map((f) => f.sequence), [4, 5]);
      expect(burst3Spec.frames.map((f) => f.sequence), [4]);
      expect(controller.state.position, const Duration(milliseconds: 5));
    });
  });
}
