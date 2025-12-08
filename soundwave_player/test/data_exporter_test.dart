import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave_player/soundwave_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DataExporter', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('soundwave_export_test');
    });

    tearDown(() async {
      if (await tmp.exists()) {
        await tmp.delete(recursive: true);
      }
    });

    test('writes wav header and samples', () async {
      final exporter = DataExporter(DataExportOptions(directoryPath: tmp.path));
      await exporter.init();

      final samples = <double>[];
      for (int i = 0; i < 8; i++) {
        samples.add(math.sin(2 * math.pi * i / 8));
      }
      await exporter.addPcmFrame(
          PcmFrame(sequence: 0, timestampMs: 0, samples: samples));
      await exporter.close();

      final wav = File('${tmp.path}/pcm_export.wav');
      expect(await wav.exists(), isTrue);
      final bytes = await wav.readAsBytes();
      // data chunk size at offset 40
      final dataSize = bytes[40] |
          (bytes[41] << 8) |
          (bytes[42] << 16) |
          (bytes[43] << 24);
      expect(dataSize, samples.length * 4);
      // RIFF header
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    });

    test('writes spectrum to csv and jsonl', () async {
      final exporter = DataExporter(DataExportOptions(directoryPath: tmp.path));
      await exporter.init();
      final bins = [0.1, 0.2, 0.3];
      await exporter.addSpectrumFrame(
          SpectrumFrame(sequence: 1, timestampMs: 10, bins: bins, binHz: 43.0));
      await exporter.close();

      final csv = await File('${tmp.path}/spectrum_export.csv').readAsString();
      expect(csv.trim().split('\n').length, 2);
      final jsonl = await File('${tmp.path}/spectrum_export.jsonl').readAsLines();
      expect(jsonl.length, 1);
      final obj = json.decode(jsonl.first) as Map<String, dynamic>;
      expect(obj['sequence'], 1);
      expect((obj['bins'] as List).length, bins.length);
    });

    test('writes debug event log when enabled', () async {
      final exporter = DataExporter(DataExportOptions(
        directoryPath: tmp.path,
        debugEventsFileName: 'events.jsonl',
      ));
      await exporter.init();
      await exporter.addPcmFrame(
          const PcmFrame(sequence: 10, timestampMs: 123, samples: [0.1, -0.1]));
      await exporter.addSpectrumFrame(const SpectrumFrame(
          sequence: 11, timestampMs: 200, bins: [0.5, 0.6], binHz: 50));
      await exporter.close();

      final lines = await File('${tmp.path}/events.jsonl').readAsLines();
      expect(lines.length, 2);
      final pcm = json.decode(lines[0]) as Map<String, dynamic>;
      final spec = json.decode(lines[1]) as Map<String, dynamic>;
      expect(pcm['type'], 'pcm');
      expect((pcm['samples'] as List).first, closeTo(0.1, 1e-6));
      expect(spec['type'], 'spectrum');
      expect(spec['binHz'], 50);
    });

    test('drops oldest pcm frames when queue is full', () async {
      final exporter = DataExporter(DataExportOptions(
        directoryPath: tmp.path,
        maxPendingPcmFrames: 2,
      ));
      await exporter.init();
      exporter.addPcmFrame(
          const PcmFrame(sequence: 0, timestampMs: 0, samples: [0, 1]));
      exporter.addPcmFrame(
          const PcmFrame(sequence: 1, timestampMs: 1, samples: [2, 3]));
      exporter.addPcmFrame(
          const PcmFrame(sequence: 2, timestampMs: 2, samples: [4, 5]));
      await exporter.close();

      expect(exporter.droppedPcmFrames, 1);
      final bytes = await File('${tmp.path}/pcm_export.wav').readAsBytes();
      final dataBytes = bytes.sublist(44);
      final dataView = ByteData.sublistView(dataBytes);
      final samples = dataView.buffer
          .asFloat32List(dataView.offsetInBytes, dataView.lengthInBytes ~/ 4)
          .toList();
      expect(samples, [2, 3, 4, 5]);
    });

    test('drops oldest spectrum frames when queue is full', () async {
      final exporter = DataExporter(DataExportOptions(
        directoryPath: tmp.path,
        maxPendingSpectrumFrames: 2,
      ));
      await exporter.init();
      exporter.addSpectrumFrame(const SpectrumFrame(
          sequence: 1, timestampMs: 10, bins: [0.1], binHz: 10));
      exporter.addSpectrumFrame(const SpectrumFrame(
          sequence: 2, timestampMs: 20, bins: [0.2], binHz: 10));
      exporter.addSpectrumFrame(const SpectrumFrame(
          sequence: 3, timestampMs: 30, bins: [0.3], binHz: 10));
      await exporter.close();

      expect(exporter.droppedSpectrumFrames, 1);
      final csvLines =
          await File('${tmp.path}/spectrum_export.csv').readAsLines();
      expect(csvLines.length, 3); // header + 2 data rows
      expect(csvLines[1].startsWith('2,'), isTrue);
      expect(csvLines[2].startsWith('3,'), isTrue);
    });
  });
}
