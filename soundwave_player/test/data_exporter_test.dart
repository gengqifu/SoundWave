import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
  });
}
