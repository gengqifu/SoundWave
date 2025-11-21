class SoundwaveConfig {
  final int sampleRate;
  final int bufferSize;
  final int channels;
  final Map<String, Object?>? visualization;

  const SoundwaveConfig({
    required this.sampleRate,
    required this.bufferSize,
    required this.channels,
    this.visualization,
  });
}
