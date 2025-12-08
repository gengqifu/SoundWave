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
  });

  /// 目标目录（需调用方确保可写，如 Android externalFilesDir / iOS documents）。
  final String directoryPath;
  final String pcmWavFileName;
  final String spectrumCsvFileName;
  final String spectrumJsonFileName;
  final int sampleRate;
  final int channels;
}

/// 管理 PCM 和谱数据导出（WAV/CSV/JSONL）。
class DataExporter {
  DataExporter(this.options);

  final DataExportOptions options;
  PcmWavWriter? _pcmWriter;
  SpectrumWriter? _spectrumWriter;

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
    return _pcmWriter?.write(frame.samples) ?? Future.value();
  }

  Future<void> addSpectrumFrame(SpectrumFrame frame) {
    return _spectrumWriter?.write(frame) ?? Future.value();
  }

  Future<void> close() async {
    await _pcmWriter?.close();
    await _spectrumWriter?.close();
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
