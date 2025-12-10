import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:soundwave_player/soundwave_player.dart';

const _defaultSource = String.fromEnvironment('SOUNDWAVE_SAMPLE_URL',
    defaultValue: 'file:///tmp/sample.mp3');

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AudioController _controller;
  final TextEditingController _sourceController =
      TextEditingController(text: _defaultSource);
  final TextEditingController _seekController =
      TextEditingController(text: '0');
  AudioState _state = AudioState.initial();
  bool _initialized = false;
  bool _pushingPcm = false;
  final List<String> _testAssets = const [
    'sine_1k.wav',
    'square_1k.wav',
    'saw_1k.wav',
    'noise_white.wav',
    'noise_pink.wav',
    'sweep_20_20k.wav',
    'silence.wav',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AudioController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _sourceController.dispose();
    _seekController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      debugPrint('Demo: init() start');
      await _controller.init(const SoundwaveConfig(
          sampleRate: 48000, bufferSize: 2048, channels: 2));
      _controller.states.listen((s) {
        setState(() {
          _state = s;
        });
        debugPrint(
            'Demo: state update playing=${s.isPlaying} buffering=${s.isBuffering} '
            'pos=${s.position.inMilliseconds} dur=${s.duration.inMilliseconds} err=${s.error}');
      });
      setState(() => _initialized = true);
      debugPrint('Demo: init() done');
    } catch (e) {
      _showError('Init failed: $e');
    }
  }

  Future<void> _load() async {
    try {
      final src = _sourceController.text.trim();
      debugPrint('Demo: load($src)');
      await _controller.load(src);
      debugPrint('Demo: load() done');
    } catch (e) {
      _showError('Load failed: $e');
    }
  }

  Future<void> _play() async {
    try {
      debugPrint('Demo: play()');
      await _controller.play();
    } catch (e) {
      _showError('Play failed: $e');
    }
  }

  Future<void> _pause() async {
    try {
      debugPrint('Demo: pause()');
      await _controller.pause();
    } catch (e) {
      _showError('Pause failed: $e');
    }
  }

  Future<void> _stop() async {
    try {
      debugPrint('Demo: stop()');
      await _controller.stop();
    } catch (e) {
      _showError('Stop failed: $e');
    }
  }

  Future<void> _useBundledSample() async {
    try {
      final data = await rootBundle.load('assets/audio/sample.mp3');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sample.mp3');
      await file.writeAsBytes(data.buffer.asUint8List());
      final path = 'file://${file.path}';
      if (!mounted) return;
      setState(() {
        _sourceController.text = path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已拷贝示例音频 sample.mp3 到本地临时目录')));
    } catch (e) {
      _showError('Load sample failed: $e');
    }
  }

  Future<void> _useBundledTest(String name) async {
    try {
      final data = await rootBundle.load('assets/audio/$name');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(data.buffer.asUint8List());
      final path = 'file://${file.path}';
      if (!mounted) return;
      setState(() {
        _sourceController.text = path;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已拷贝 $name 到本地临时目录')));
    } catch (e) {
      _showError('Load $name failed: $e');
    }
  }

  Future<void> _seek() async {
    try {
      final ms = int.tryParse(_seekController.text.trim()) ?? 0;
      debugPrint('Demo: seek($ms ms)');
      await _controller.seek(Duration(milliseconds: ms));
    } catch (e) {
      _showError('Seek failed: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<_WavData> _decodePcmWav(String asset) async {
    final data = await rootBundle.load(asset);
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    if (bytes.lengthInBytes < 44) {
      throw StateError('WAV header too short for $asset');
    }
    final header = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (header != 'RIFF' || wave != 'WAVE') {
      throw StateError('仅支持 PCM WAV 资产，当前为 $header/$wave');
    }
    final bd =
        ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
    final audioFormat = bd.getUint16(20, Endian.little);
    final channels = bd.getUint16(22, Endian.little);
    final sampleRate = bd.getUint32(24, Endian.little);
    final bitsPerSample = bd.getUint16(34, Endian.little);
    if (audioFormat != 1 || bitsPerSample != 16) {
      throw StateError(
          '仅支持 16-bit PCM WAV，当前 format=$audioFormat bits=$bitsPerSample');
    }

    int offset = 12;
    int? dataOffset;
    int? dataSize;
    while (offset + 8 <= bytes.lengthInBytes) {
      final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bd.getUint32(offset + 4, Endian.little);
      if (chunkId == 'data') {
        dataOffset = offset + 8;
        dataSize = math.min(chunkSize, bytes.lengthInBytes - dataOffset);
        break;
      }
      offset += 8 + chunkSize;
    }
    if (dataOffset == null || dataSize == null || dataSize <= 0) {
      throw StateError('未找到 data chunk');
    }

    final sampleCount = dataSize ~/ 2;
    final samples = List<double>.filled(sampleCount, 0.0, growable: false);
    for (int i = 0; i < sampleCount; i++) {
      final raw = bd.getInt16(dataOffset + i * 2, Endian.little);
      samples[i] = raw / 32768.0;
    }
    return _WavData(
        sampleRate: sampleRate, channels: channels, samples: samples);
  }

  Future<void> _pushPcmFromAsset(String name) async {
    if (!_initialized || _pushingPcm) return;
    setState(() => _pushingPcm = true);
    try {
      await _controller.subscribeWaveform();
      await _controller.subscribeSpectrum();
      final wav = await _decodePcmWav('assets/audio/$name');
      const frameSamples = 1024;
      int sequence = 0;
      for (int offset = 0;
          offset < wav.samples.length;
          offset += frameSamples * wav.channels) {
        final end =
            math.min(wav.samples.length, offset + frameSamples * wav.channels);
        final chunk = wav.samples.sublist(offset, end);
        final timestampMs =
            ((offset / wav.channels) / wav.sampleRate * 1000).round();
        final frame = PcmInputFrame(
            samples: chunk,
            sampleRate: wav.sampleRate,
            channels: wav.channels,
            timestampMs: timestampMs,
            sequence: sequence++);
        await _controller.pushPcmFrame(frame);
      }
      _showSnack('已推送 PCM 帧 $sequence 个（$name）');
    } catch (e) {
      _showError('Push PCM failed: $e');
    } finally {
      if (mounted) {
        setState(() => _pushingPcm = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('SoundWave Demo (local playback)'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              TextField(
                controller: _sourceController,
                decoration: const InputDecoration(
                    labelText: 'Source (file:// or http://)'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                      onPressed: _useBundledSample,
                      child: const Text('Use bundled sample.mp3')),
                  ..._testAssets.map(
                    (name) => OutlinedButton(
                      onPressed: () => _useBundledTest(name),
                      child: Text('Use $name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                      onPressed: _initialized ? null : _init,
                      child: const Text('Init')),
                  ElevatedButton(
                      onPressed: _initialized ? _load : null,
                      child: const Text('Load')),
                  ElevatedButton(
                      onPressed: _initialized ? _play : null,
                      child: const Text('Play')),
                  ElevatedButton(
                      onPressed: _initialized ? _pause : null,
                      child: const Text('Pause')),
                  ElevatedButton(
                      onPressed: _initialized ? _stop : null,
                      child: const Text('Stop')),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: (_initialized && !_pushingPcm)
                        ? () => _pushPcmFromAsset('sine_1k.wav')
                        : null,
                    child: Text(
                        _pushingPcm ? 'Pushing PCM...' : 'Push PCM (sine_1k)'),
                  ),
                  OutlinedButton(
                    onPressed: (_initialized && !_pushingPcm)
                        ? () => _pushPcmFromAsset('square_1k.wav')
                        : null,
                    child: const Text('Push PCM (square_1k)'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _seekController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Seek ms'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                      onPressed: _initialized ? _seek : null,
                      child: const Text('Seek')),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                  'Status: playing=${_state.isPlaying}, buffering=${_state.isBuffering}'),
              Text('Position: ${_state.position.inMilliseconds} ms'),
              Text('Duration: ${_state.duration.inMilliseconds} ms'),
              if (_state.error != null)
                Text('Error: ${_state.error}',
                    style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              if (_initialized)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Waveform'),
                    SizedBox(
                      height: 120,
                      child: WaveformStreamView(
                        buffer: _controller.pcmBuffer,
                        background: Colors.black,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Spectrum'),
                    SizedBox(
                      height: 140,
                      child: SpectrumStreamView(
                        buffer: _controller.spectrumBuffer,
                        // 与测试用例一致：线性频率轴 + 幅度对数压缩，便于对齐 golden。
                        style: const SpectrumStyle(
                          freqLogScale: false,
                          logScale: true,
                          background: Colors.black,
                          barColor: Colors.cyan,
                        ),
                      ),
                    ),
                  ],
                )
              else
                const Text('Init 后显示波形/频谱'),
            ],
          ),
        ),
      ),
    );
  }
}

class _WavData {
  const _WavData({
    required this.sampleRate,
    required this.channels,
    required this.samples,
  });

  final int sampleRate;
  final int channels;
  final List<double> samples;
}
