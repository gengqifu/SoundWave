# 长稳与性能基线记录模板

用于记录连续播放 ≥60min 的长稳与性能数据。按平台填写实测值，作为回归基线。

## 记录示例（请替换为实测数据）
- 设备/OS：Pixel 6 (Android 14) / iPhone 14 (iOS 17.x)
- 构建类型：Release / Debug
- 音频：sample.wav / sweep_20_20k.wav
- 播放总时长：XX 分钟
- 前后台切换次数：N 次（含锁屏/解锁）
- 波形/频谱中断：无 / 有（描述）
- 错误/崩溃：无 / 有（描述）
- 结论：通过 / 需修复

## 指标表（请补充）

| 平台 | CPU 峰值 / 平均 | 内存峰值 / 增长 | 帧率/渲染表现 | 备注 |
| --- | --- | --- | --- | --- |
| Android Host | TODO | TODO | TODO |  |
| iOS Host | TODO | TODO | TODO |  |
| Flutter 示例 | TODO | TODO | TODO |  |

## 步骤参考
- Flutter 示例：参见 `soundwave_player/scripts/long_run_smoke.sh` 或 `docs/tests/longrun_performance.md`。
- Android Host：使用 Profiler/adb logcat 记录 CPU/内存，前后台各 30min。
- iOS Host：使用 Xcode gauge / Instruments 记录 CPU/内存，前后台各 30min。
