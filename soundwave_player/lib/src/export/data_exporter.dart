import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../pcm_frame.dart';
import '../spectrum_frame.dart';

class DataExportOptions {
  const DataExportOptions({
    required this.directoryPath,
    this.pcmWavFileName = 'pcm_export.wav',
    this.spectrumCsvFileName = 'spectrum_export.csv',
    this.spectrumJsonFileName = 'spectrum_export.jsonl',
    this.sampleRate = 44100,
    this.channels = 2,
    this.maxPendingPcmFrames = 32,
    this.maxPendingSpectrumFrames = 32,
  });

  /// 目标目录（需调用方确保可写，如 Android externalFilesDir / iOS documents）。
  final String directoryPath;
  final String pcmWavFileName;
  final String spectrumCsvFileName;
  final String spectrumJsonFileName;
  final int sampleRate;
  final int channels;
  final int maxPendingPcmFrames;
  final int maxPendingSpectrumFrames;
}

/// 管理 PCM 和谱数据导出（WAV/CSV/JSONL）。
class DataExporter {
  DataExporter(this.options);

  final DataExportOptions options;
  PcmWavWriter? _pcmWriter;
  SpectrumWriter? _spectrumWriter;
  final ListQueue<_FrameJob<PcmFrame>> _pcmQueue = ListQueue<_FrameJob<PcmFrame>>();
  final ListQueue<_FrameJob<SpectrumFrame>> _spectrumQueue =
      ListQueue<_FrameJob<SpectrumFrame>>();
  int _pcmDropped = 0;
  int _spectrumDropped = 0;
  bool _pcmDraining = false;
  bool _spectrumDraining = false;
  Future<void>? _pcmDrainFuture;
  Future<void>? _spectrumDrainFuture;

  Future<void> init() async {
    final dir = Directory(options.directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _pcmWriter = PcmWavWriter(
      file: File('${options.directoryPath}/${options.pcmWavFileName}'),
      sampleRate: options.sampleRate,
      channels: options.channels,
    );
    _spectrumWriter = SpectrumWriter(
      csvFile: File('${options.directoryPath}/${options.spectrumCsvFileName}'),
      jsonlFile: File('${options.directoryPath}/${options.spectrumJsonFileName}'),
    );
  }

  Future<void> addPcmFrame(PcmFrame frame) {
    final writer = _pcmWriter;
    if (writer == null) return Future.value();
    final job = _FrameJob<PcmFrame>(frame);
    _enqueuePcm(job);
    _kickPcmDrain(writer);
    return job.completer.future;
  }

  Future<void> addSpectrumFrame(SpectrumFrame frame) {
    final writer = _spectrumWriter;
    if (writer == null) return Future.value();
    final job = _FrameJob<SpectrumFrame>(frame);
    _enqueueSpectrum(job);
    _kickSpectrumDrain(writer);
    return job.completer.future;
  }

  Future<void> close() async {
    await _waitForPending();
    await _pcmWriter?.close();
    await _spectrumWriter?.close();
  }

  int get droppedPcmFrames => _pcmDropped;
  int get droppedSpectrumFrames => _spectrumDropped;

  void _enqueuePcm(_FrameJob<PcmFrame> job) {
    _pcmQueue.addLast(job);
    if (_pcmQueue.length > options.maxPendingPcmFrames) {
      final removed = _pcmQueue.removeFirst();
      _pcmDropped++;
      removed.completer.complete(); // 视为已处理，防止等待泄漏。
    }
  }

  void _enqueueSpectrum(_FrameJob<SpectrumFrame> job) {
    _spectrumQueue.addLast(job);
    if (_spectrumQueue.length > options.maxPendingSpectrumFrames) {
      final removed = _spectrumQueue.removeFirst();
      _spectrumDropped++;
      removed.completer.complete();
    }
  }

  void _kickPcmDrain(PcmWavWriter writer) {
    if (_pcmDraining) return;
    _pcmDraining = true;
    _pcmDrainFuture = Future<void>(() async {
      while (_pcmQueue.isNotEmpty) {
        final job = _pcmQueue.removeFirst();
        try {
          await writer.write(job.frame.samples);
          job.completer.complete();
        } catch (e, st) {
          job.completer.completeError(e, st);
        }
      }
      _pcmDraining = false;
      if (_pcmQueue.isNotEmpty) {
        _kickPcmDrain(writer);
      }
    });
  }

  void _kickSpectrumDrain(SpectrumWriter writer) {
    if (_spectrumDraining) return;
    _spectrumDraining = true;
    _spectrumDrainFuture = Future<void>(() async {
      while (_spectrumQueue.isNotEmpty) {
        final job = _spectrumQueue.removeFirst();
        try {
          await writer.write(job.frame);
          job.completer.complete();
        } catch (e, st) {
          job.completer.completeError(e, st);
        }
      }
      _spectrumDraining = false;
      if (_spectrumQueue.isNotEmpty) {
        _kickSpectrumDrain(writer);
      }
    });
  }

  Future<void> _waitForPending() async {
    if (_pcmDrainFuture != null) {
      await _pcmDrainFuture;
    }
    if (_spectrumDrainFuture != null) {
      await _spectrumDrainFuture;
    }
  }
}

class PcmWavWriter {
  PcmWavWriter({
    required this.file,
    required this.sampleRate,
    required this.channels,
  });

  final File file;
  final int sampleRate;
  final int channels;
  RandomAccessFile? _raf;
  int _samplesWritten = 0; // sample count per channel interleaved

  Future<void> _ensureOpen() async {
    if (_raf != null) return;
    _raf = await file.open(mode: FileMode.write);
    // reserve 44 bytes for WAV header
    await _raf!.writeFrom(List<int>.filled(44, 0));
  }

  Future<void> write(List<double> samples) async {
    if (samples.isEmpty) return;
    await _ensureOpen();
    final raf = _raf!;
    final floatList = Float32List.fromList(samples.map((e) => e.toDouble()).toList());
    final bytes = floatList.buffer.asUint8List();
    await raf.writeFrom(bytes);
    _samplesWritten += samples.length;
  }

  Future<void> close() async {
    final raf = _raf;
    if (raf == null) return;
    final dataSize = _samplesWritten * 4; // float32 bytes
    await raf.setPosition(0);
    final header = _buildHeader(dataSize);
    await raf.writeFrom(header);
    await raf.close();
    _raf = null;
  }

  List<int> _buildHeader(int dataSize) {
    final byteData = ByteData(44);
    void writeString(int offset, String value) {
      for (int i = 0; i < value.length; i++) {
        byteData.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    byteData.setUint32(4, 36 + dataSize, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little); // PCM chunk size
    byteData.setUint16(20, 3, Endian.little); // format: IEEE float
    byteData.setUint16(22, channels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    final byteRate = sampleRate * channels * 4;
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, (channels * 4), Endian.little); // block align
    byteData.setUint16(34, 32, Endian.little); // bits per sample
    writeString(36, 'data');
    byteData.setUint32(40, dataSize, Endian.little);
    return byteData.buffer.asUint8List();
  }
}

class SpectrumWriter {
  SpectrumWriter({required this.csvFile, required this.jsonlFile});

  final File csvFile;
  final File jsonlFile;
  IOSink? _csvSink;
  IOSink? _jsonSink;
  bool _csvHeaderWritten = false;
  int _binCount = 0;

  Future<void> _ensureOpen() async {
    _csvSink ??= csvFile.openWrite();
    _jsonSink ??= jsonlFile.openWrite();
  }

  Future<void> write(SpectrumFrame frame) async {
    await _ensureOpen();
    _binCount = frame.bins.length;
    if (!_csvHeaderWritten) {
      final header = [
        'sequence',
        'timestampMs',
        'binHz',
        ...List<String>.generate(_binCount, (i) => 'bin$i'),
      ];
      _csvSink!.writeln(header.join(','));
      _csvHeaderWritten = true;
    }
    final row = <String>[
      frame.sequence.toString(),
      frame.timestampMs.toString(),
      frame.binHz.toString(),
      ...frame.bins.map((b) => b.toString()),
    ];
    _csvSink!.writeln(row.join(','));

    final jsonObj = {
      'sequence': frame.sequence,
      'timestampMs': frame.timestampMs,
      'binHz': frame.binHz,
      'bins': frame.bins,
    };
    _jsonSink!.writeln(jsonEncode(jsonObj));
  }

  Future<void> close() async {
    await _csvSink?.flush();
    await _csvSink?.close();
    await _jsonSink?.flush();
    await _jsonSink?.close();
    _csvSink = null;
    _jsonSink = null;
  }
}

class _FrameJob<T> {
  _FrameJob(this.frame) : completer = Completer<void>();

  final T frame;
  final Completer<void> completer;
}
