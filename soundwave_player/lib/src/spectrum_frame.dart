class SpectrumFrame {
  const SpectrumFrame({
    required this.sequence,
    required this.timestampMs,
    required this.bins,
    required this.binHz,
  });

  final int sequence;
  final int timestampMs;
  final List<double> bins;
  final double binHz;
}
