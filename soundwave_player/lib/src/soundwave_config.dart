class SoundwaveConfig {
  final int sampleRate;
  final int bufferSize;
  final int channels;
  final int? pcmMaxFps;
  final int? pcmFramesPerPush;
  final int? pcmMaxPending;
  final int? spectrumMaxFps;
  final int? spectrumMaxPending;
  final int? connectTimeoutMs;
  final int? readTimeoutMs;
  final bool? enableRangeRequests;
  final int? ringBufferMs;
  final bool? enableSkiaTracing;
  final ExportConfig? export;

  const SoundwaveConfig({
    required this.sampleRate,
    required this.bufferSize,
    required this.channels,
    this.pcmMaxFps,
    this.pcmFramesPerPush,
    this.pcmMaxPending,
    this.spectrumMaxFps,
    this.spectrumMaxPending,
    this.connectTimeoutMs,
    this.readTimeoutMs,
    this.enableRangeRequests,
    this.ringBufferMs,
    this.enableSkiaTracing,
    this.export,
  });

  void validate() {
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate', 'must be > 0');
    }
    if (bufferSize <= 0) {
      throw ArgumentError.value(bufferSize, 'bufferSize', 'must be > 0');
    }
    if (channels <= 0) {
      throw ArgumentError.value(channels, 'channels', 'must be > 0');
    }
    if (pcmMaxFps != null && pcmMaxFps! <= 0) {
      throw ArgumentError.value(pcmMaxFps, 'pcmMaxFps', 'must be > 0');
    }
    if (pcmFramesPerPush != null && pcmFramesPerPush! <= 0) {
      throw ArgumentError.value(pcmFramesPerPush, 'pcmFramesPerPush', 'must be > 0');
    }
    if (pcmMaxPending != null && pcmMaxPending! < 0) {
      throw ArgumentError.value(pcmMaxPending, 'pcmMaxPending', 'must be >= 0');
    }
    if (spectrumMaxFps != null && spectrumMaxFps! <= 0) {
      throw ArgumentError.value(spectrumMaxFps, 'spectrumMaxFps', 'must be > 0');
    }
    if (spectrumMaxPending != null && spectrumMaxPending! < 0) {
      throw ArgumentError.value(spectrumMaxPending, 'spectrumMaxPending', 'must be >= 0');
    }
    if (connectTimeoutMs != null && connectTimeoutMs! <= 0) {
      throw ArgumentError.value(connectTimeoutMs, 'connectTimeoutMs', 'must be > 0');
    }
    if (readTimeoutMs != null && readTimeoutMs! <= 0) {
      throw ArgumentError.value(readTimeoutMs, 'readTimeoutMs', 'must be > 0');
    }
    if (ringBufferMs != null && ringBufferMs! <= 0) {
      throw ArgumentError.value(ringBufferMs, 'ringBufferMs', 'must be > 0');
    }
    export?.validate();
  }

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'sampleRate': sampleRate,
      'bufferSize': bufferSize,
      'channels': channels,
    };
    final network = <String, Object?>{};
    if (connectTimeoutMs != null) network['connectTimeoutMs'] = connectTimeoutMs;
    if (readTimeoutMs != null) network['readTimeoutMs'] = readTimeoutMs;
    if (enableRangeRequests != null) network['enableRangeRequests'] = enableRangeRequests;
    if (network.isNotEmpty) {
      map['network'] = network;
    }
    final playback = <String, Object?>{};
    if (ringBufferMs != null) playback['ringBufferMs'] = ringBufferMs;
    if (playback.isNotEmpty) {
      map['playback'] = playback;
    }
    final visualization = <String, Object?>{};
    if (pcmMaxFps != null) visualization['pcmMaxFps'] = pcmMaxFps;
    if (pcmFramesPerPush != null) visualization['pcmFramesPerPush'] = pcmFramesPerPush;
    if (pcmMaxPending != null) visualization['pcmMaxPending'] = pcmMaxPending;
    if (spectrumMaxFps != null) visualization['spectrumMaxFps'] = spectrumMaxFps;
    if (spectrumMaxPending != null) visualization['spectrumMaxPending'] = spectrumMaxPending;
    if (enableSkiaTracing != null) visualization['enableSkiaTracing'] = enableSkiaTracing;
    if (visualization.isNotEmpty) {
      map['visualization'] = visualization;
    }
    if (export != null) {
      map['export'] = export!.toMap();
    }
    return map;
  }
}

class ExportConfig {
  const ExportConfig({
    required this.directoryPath,
    this.filePrefix = 'soundwave',
    this.enablePcm = true,
    this.enableSpectrum = true,
  });

  final String directoryPath;
  final String filePrefix;
  final bool enablePcm;
  final bool enableSpectrum;

  void validate() {
    if (directoryPath.trim().isEmpty) {
      throw ArgumentError.value(directoryPath, 'directoryPath', 'cannot be empty');
    }
  }

  Map<String, Object?> toMap() {
    return {
      'directoryPath': directoryPath,
      'filePrefix': filePrefix,
      'enablePcm': enablePcm,
      'enableSpectrum': enableSpectrum,
    };
  }
}
