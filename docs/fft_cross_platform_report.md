# FFT 跨端对齐报告

## 参考基线
- 生成脚本：`tools/fft_reference.py`（Hann+nfft=1024，归一化 2/(N*E_window)，fs=44.1k，纯 Python fallback，无外部依赖）
- 信号/文件：`docs/fft_reference_{single,double,white,sweep}.json`
  - single: peak_bin=23, peak_mag=0.0012620387369490437
  - double: peak_bin=10, peak_mag=0.0012628887388303474
  - white: peak_bin=469, peak_mag=0.0001524022139339323
  - sweep: peak_bin=12, peak_mag=0.00018295026675584083

## Android (KissFFT JNI)
- 已对照 `docs/fft_reference_{single,double,white,sweep}.json`：
  - single: peak_bin=23 / 0.00126204，L2=3.82e-09，Max=8.32e-10
  - double: peak_bin=10 / 0.00126289，L2=3.56e-09，Max=6.39e-10
  - white: peak_bin=116 / 0.000144829，L2=8.23e-04，Max=1.23e-04（随机差异内，<1e-3）
  - sweep: peak_bin=12 / 0.000182952，L2=3.31e-08，Max=4.47e-09
- 运行：`cd native/core && cmake -S . -B build && cmake --build build --target fft_compare && ./build/fft_compare ../../docs/fft_reference_single.json`（依次替换文件）。

## iOS (vDSP/Swift FFT)
- TODO：同上，对照 JSON 验证 vDSP/Swift FFT 输出，误差阈值：L2/Max < 1e-3。记录设备/环境。

## 误差评估
- TODO：填充各信号的 L2/Max 误差，汇总表。

## 结论
- TODO：待两端跑完对齐测试后更新。
