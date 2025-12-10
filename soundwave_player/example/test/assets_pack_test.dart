import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const audioAssets = <String>[
    'assets/audio/sample.mp3',
    'assets/audio/sample.wav',
    'assets/audio/sine_1k.wav',
    'assets/audio/square_1k.wav',
    'assets/audio/saw_1k.wav',
    'assets/audio/sweep_20_20k.wav',
    'assets/audio/noise_white.wav',
    'assets/audio/noise_pink.wav',
    'assets/audio/silence.wav',
  ];

  Future<Set<String>> _loadAssetManifest() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifest = jsonDecode(manifestContent);
    return manifest.keys.toSet();
  }

  test('example audio assets are declared and loadable', () async {
    final manifestAssets = await _loadAssetManifest();

    for (final asset in audioAssets) {
      expect(manifestAssets.contains(asset), isTrue,
          reason: 'AssetManifest should include $asset');
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0),
          reason: 'Asset $asset should be packaged with non-empty content');
    }
  });
}
