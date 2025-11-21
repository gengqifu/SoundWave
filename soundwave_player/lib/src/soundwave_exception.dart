class SoundwaveException implements Exception {
  final String code;
  final String message;
  final Object? details;

  const SoundwaveException(this.code, this.message, [this.details]);

  @override
  String toString() => 'SoundwaveException($code): $message';
}
