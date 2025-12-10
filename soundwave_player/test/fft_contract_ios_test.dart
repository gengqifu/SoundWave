import 'package:flutter_test/flutter_test.dart';

/// 面向 iOS 原生 FFT 的契约测试（占位）。
/// TODO: 实现 KissFFT 后取消 skip，验证频谱正确性与桥接。
void main() {
  group('iOS FFT contract', () {
    test(
      'native FFT emits spectrum bins for 1kHz sine',
      () {
        expect(true, isTrue);
      },
      skip: 'Pending iOS core KissFFT implementation',
    );
  });
}
