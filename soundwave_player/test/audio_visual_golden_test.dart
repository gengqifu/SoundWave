import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

class _WavData {
  _WavData({required this.sampleRate, required this.channels, required this.samples});
  final int sampleRate;
  final int channels;
  final List<double> samples; // 归一化到 [-1, 1]，单通道
}

Future<_WavData> _loadPcm16Wav(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asByteData();
  int offset = 0;
  String readTag() {
    final codes = <int>[];
    for (int i = 0; i < 4; i++) {
      codes.add(bytes.getUint8(offset + i));
    }
    offset += 4;
    return String.fromCharCodes(codes);
  }

  int readUint32() {
    final v = bytes.getUint32(offset, Endian.little);
    offset += 4;
    return v;
  }

  // RIFF header
  if (readTag() != 'RIFF') throw StateError('not RIFF');
  offset += 4; // chunk size
  if (readTag() != 'WAVE') throw StateError('not WAVE');

  int sampleRate = 0;
  int channels = 1;
  int bitsPerSample = 16;
  int dataOffset = -1;
  int dataSize = 0;

  while (offset + 8 <= bytes.lengthInBytes) {
    final tag = readTag();
    final size = readUint32();
    if (tag == 'fmt ') {
      channels = bytes.getUint16(offset + 2, Endian.little);
      sampleRate = bytes.getUint32(offset + 4, Endian.little);
      bitsPerSample = bytes.getUint16(offset + 14, Endian.little);
    } else if (tag == 'data') {
      dataOffset = offset;
      dataSize = size;
    }
    offset += size;
  }
  if (dataOffset < 0 || sampleRate <= 0 || bitsPerSample != 16) {
    throw StateError('Invalid wav: $assetPath');
  }

  final bytesPerSample = (bitsPerSample ~/ 8) * channels;
  final int sampleCount = dataSize ~/ bytesPerSample;
  final List<double> samples = List<double>.filled(sampleCount, 0);
  for (int i = 0; i < sampleCount; i++) {
    final base = dataOffset + i * bytesPerSample;
    final int sample = bytes.getInt16(base, Endian.little);
    samples[i] = sample / 32768.0;
  }

  return _WavData(sampleRate: sampleRate, channels: channels, samples: samples);
}

List<double> _computeSpectrum(List<double> samples, int sampleRate, {int n = 1024}) {
  if (samples.isEmpty) return const [];
  final len = math.min(samples.length, n);
  final re = List<double>.filled(len, 0);
  final im = List<double>.filled(len, 0);
  // Hann window
  for (int i = 0; i < len; i++) {
    final w = 0.5 * (1 - math.cos(2 * math.pi * i / (len - 1)));
    re[i] = samples[i] * w;
  }
  // naive DFT O(n^2) for test
  final int kMax = len ~/ 2;
  final bins = List<double>.filled(kMax, 0);
  for (int k = 0; k < kMax; k++) {
    double r = 0, m = 0;
    for (int t = 0; t < len; t++) {
      final angle = -2 * math.pi * k * t / len;
      final c = math.cos(angle);
      final s = math.sin(angle);
      r += re[t] * c - im[t] * s; // im[] = 0
      m += re[t] * s + im[t] * c;
    }
    bins[k] = math.sqrt(r * r + m * m);
  }
  return bins;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> _renderWaveformGolden(WidgetTester tester,
      {required String asset, required String golden}) async {
    final wav = await _loadPcm16Wav(asset);
    final frame = PcmFrame(sequence: 0, timestampMs: 0, samples: wav.samples);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 120,
          child: WaveformView(
            frames: [frame],
            background: Colors.black,
            color: Colors.cyan,
            strokeWidth: 1.5,
          ),
        ),
      ),
    ));

    await expectLater(
      find.byType(WaveformView),
      matchesGoldenFile(golden),
    );
  }

  Future<void> _renderSpectrumGolden(WidgetTester tester,
      {required String asset, required String golden}) async {
    final wav = await _loadPcm16Wav(asset);
    final bins = _computeSpectrum(wav.samples, wav.sampleRate);
    final binHz = wav.sampleRate / math.min(wav.samples.length, 1024);
    final spectrumBins = <SpectrumBin>[];
    for (int i = 0; i < bins.length; i++) {
      spectrumBins.add(SpectrumBin(frequency: i * binHz, magnitude: bins[i]));
    }

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 140,
          child: SpectrumView(
            bins: spectrumBins,
            style: const SpectrumStyle(
              barColor: Colors.cyan,
              background: Colors.black,
              freqLogScale: false, // 线性频率轴便于黄金稳定
              logScale: true,
            ),
          ),
        ),
      ),
    ));

    await expectLater(
      find.byType(SpectrumView),
      matchesGoldenFile(golden),
    );
  }

  testWidgets('Waveform/Spectrum golden: sine 1kHz', (tester) async {
    await _renderWaveformGolden(tester,
        asset: 'test/assets/audio/sine_1k.wav',
        golden: 'goldens/waveform_sine_1k.png');
    await _renderSpectrumGolden(tester,
        asset: 'test/assets/audio/sine_1k.wav',
        golden: 'goldens/spectrum_sine_1k.png');
  });

  testWidgets('Waveform/Spectrum golden: square 1kHz', (tester) async {
    await _renderWaveformGolden(tester,
        asset: 'test/assets/audio/square_1k.wav',
        golden: 'goldens/waveform_square_1k.png');
    await _renderSpectrumGolden(tester,
        asset: 'test/assets/audio/square_1k.wav',
        golden: 'goldens/spectrum_square_1k.png');
  });

  testWidgets('Waveform/Spectrum golden: saw 1kHz', (tester) async {
    await _renderWaveformGolden(tester,
        asset: 'test/assets/audio/saw_1k.wav',
        golden: 'goldens/waveform_saw_1k.png');
    await _renderSpectrumGolden(tester,
        asset: 'test/assets/audio/saw_1k.wav',
        golden: 'goldens/spectrum_saw_1k.png');
  });

  testWidgets('Waveform/Spectrum golden: white noise', (tester) async {
    await _renderWaveformGolden(tester,
        asset: 'test/assets/audio/noise_white.wav',
        golden: 'goldens/waveform_noise_white.png');
    await _renderSpectrumGolden(tester,
        asset: 'test/assets/audio/noise_white.wav',
        golden: 'goldens/spectrum_noise_white.png');
  });

  testWidgets('Waveform/Spectrum golden: pink noise', (tester) async {
    await _renderWaveformGolden(tester,
        asset: 'test/assets/audio/noise_pink.wav',
        golden: 'goldens/waveform_noise_pink.png');
    await _renderSpectrumGolden(tester,
        asset: 'test/assets/audio/noise_pink.wav',
        golden: 'goldens/spectrum_noise_pink.png');
  });

  testWidgets('Waveform/Spectrum golden: sweep 20-20k', (tester) async {
    await _renderWaveformGolden(tester,
        asset: 'test/assets/audio/sweep_20_20k.wav',
        golden: 'goldens/waveform_sweep.png');
    await _renderSpectrumGolden(tester,
        asset: 'test/assets/audio/sweep_20_20k.wav',
        golden: 'goldens/spectrum_sweep.png');
  });
}
