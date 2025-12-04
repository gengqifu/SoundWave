import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:soundwave_player/soundwave_player.dart';

const _defaultSource =
    String.fromEnvironment('SOUNDWAVE_SAMPLE_URL', defaultValue: 'file:///tmp/sample.mp3');

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
  final TextEditingController _sourceController = TextEditingController(text: _defaultSource);
  final TextEditingController _seekController = TextEditingController(text: '0');
  AudioState _state = AudioState.initial();
  bool _initialized = false;

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
      await _controller.init(const SoundwaveConfig(sampleRate: 48000, bufferSize: 2048, channels: 2));
      _controller.states.listen((s) {
        setState(() {
          _state = s;
        });
        debugPrint('Demo: state update playing=${s.isPlaying} buffering=${s.isBuffering} '
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
      setState(() {
        _sourceController.text = path;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已拷贝示例音频 sample.mp3 到本地临时目录')));
    } catch (e) {
      _showError('Load sample failed: $e');
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
                decoration: const InputDecoration(labelText: 'Source (file:// or http://)'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(onPressed: _useBundledSample, child: const Text('Use bundled sample.mp3')),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(onPressed: _initialized ? null : _init, child: const Text('Init')),
                  ElevatedButton(onPressed: _initialized ? _load : null, child: const Text('Load')),
                  ElevatedButton(onPressed: _initialized ? _play : null, child: const Text('Play')),
                  ElevatedButton(onPressed: _initialized ? _pause : null, child: const Text('Pause')),
                  ElevatedButton(onPressed: _initialized ? _stop : null, child: const Text('Stop')),
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
                  ElevatedButton(onPressed: _initialized ? _seek : null, child: const Text('Seek')),
                ],
              ),
              const SizedBox(height: 12),
              Text('Status: playing=${_state.isPlaying}, buffering=${_state.isBuffering}'),
              Text('Position: ${_state.position.inMilliseconds} ms'),
              Text('Duration: ${_state.duration.inMilliseconds} ms'),
              if (_state.error != null) Text('Error: ${_state.error}', style: const TextStyle(color: Colors.red)),
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
