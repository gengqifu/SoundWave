# SoundWave 0.0.2 技术方案

## 1. 背景与目标
- 去除 FFmpeg 依赖，改用平台解码器以降低许可证风险与包体体积。
- FFT 库选型：Android 只使用 KissFFT（JNI）；iOS 默认使用 Accelerate/vDSP，同时提供可选 KissFFT（用于一致性/测试，demo 可切换）。
- 将 PCM 波形与 FFT 频谱的采集/计算/导出能力从示例抽离为可复用库，支持 Maven（Android）与 pub（Flutter）发布，既可源码依赖也可二进制依赖。
- 在移除 FFmpeg 后统一使用 Apache-2.0 许可证，更新文档与合规声明。
- 新增测试工具场景：受测 App 已有解码能力，本插件作为旁路输出 PCM/频域数据，可保存为通用格式（如 WAV/CSV/JSON）供 PC 第三方音频分析；移动端可视化作为可选扩展/后门开关，播放过程中即时观察波形/谱。

## 2. 方案概览
- 解码链路：ExoPlayer（MediaCodec）/AVFoundation 直出 PCM，保持现有环形缓冲与节流策略；FFmpeg/CMake 相关全部移除。
- FFT：Android JNI 调用 C/C++ KissFFT（唯一实现，窗口化 + 功率谱）；iOS 默认 vDSP，提供可切换的 KissFFT 选项（用于一致性/低依赖场景）；两端保持统一窗口参数与输出格式。
- 组件化：抽象“可视化管线”库，含 PCM tap、FFT、节流、事件模型与导出 API；Flutter 层提供 Dart 包包装；Android 侧提供独立 AAR。
- License：切换为 Apache-2.0，删改 GPL 相关文本；确保依赖链（ExoPlayer、vDSP、KissFFT）与 License 兼容，并提供 NOTICE/DEPENDENCIES。
- 测试工具输出：旁路 PCM/谱数据支持本地存储（WAV/CSV/JSON），可离线导出到 PC；移动端可视化为可选模块，由受测 App 通过隐藏开关调出。

## 3. 关键改动与接口
### 3.1 解码与数据流
- 输出规范：平台解码统一输出 44.1 kHz、float32、立体声；若源与目标不一致则重采样/格式转换（16-bit → float32），Playback 仍走双声道，FFT 输入先 downmix `(L+R)/2`。
- Android：保留 ExoPlayer/AudioSink，自定义 AudioProcessor 旁路 PCM；删除 FFmpeg so/headers/CMake 条目；剔除 native 解码路径与相关测试。
- iOS：AVPlayer + tap 输出 PCM；删除 FFmpeg 适配代码和二进制；保持 EventChannel 推送。
- 数据流：解码 → PCM 缓冲 → 节流 → PCM 事件 + FFT 事件；FFT 的输入从 PCM tap 复用。

### 3.2 FFT 选型
- Android：JNI 桥接 `kissfft`（CMake 编译为静态/共享），提供 `computeSpectrum(float[] samples, int nfft, WindowType, overlap)`；Kotlin 自写 FFT 删除，不保留 fallback。
- iOS：默认 vDSP FFT，接口与 Android 对齐；额外提供可选 KissFFT（同一接口），在 demo 中可切换以做跨端一致性对比或规避 Accelerate 依赖。
- FFT 规范：窗口 Hann（默认）/Hamming，功率谱归一化 `2 / (N * E_window)`（E_window 为窗口能量），幅度结果保持与输入幅值一致；nfft 默认 1024、overlap 默认 50%；多声道统一在 FFT 前 downmix；vDSP/KissFFT 按相同归一化因子输出，跨端容差 < 1e-3。
- 输出格式：`bins: FloatArray`, `binHz = sampleRate / nfft`, `window = Hann/Hamming`, `seq/timestamp` 保持现状。

### 3.3 组件化与发布
- Android：拆出 `visualization-core`（PCM tap + FFT + 节流 + 元数据模型），发布到 Maven（groupId `com.soundwave`, artifactId `visualization-core`）；插件依赖该 AAR，版本遵循 semver，与 Dart 包保持主版本一致（如 0.0.x → 0.0.x）。
- iOS：抽出可视化能力为独立 CocoaPods（pod 名：`SoundwaveVisualization`）与 Swift Package（包名同 pod），封装 PCM tap + vDSP FFT（默认）+ KissFFT（可选）+ 节流/事件模型；支持 XCFramework/源码两种形态；版本与 Android/Dart 对齐（同主次版本）。
- Flutter/Dart：新建 `soundwave_visualization` 包，暴露 `PcmFrame` / `SpectrumFrame` / 绘制组件；支持 path/pub 依赖；示例锁定同版本；遵循 semver，与原生产物的主次版本同步。
- 示例/demo 仅作为集成验证，不再承载核心逻辑。
- 测试工具扩展：提供可插拔“数据导出”模块（WAV/CSV/JSON）与“可视化后门”模块；受测 App 可按需依赖，仅导出不必引入 UI。

### 3.4 License
- 目标 License：Apache-2.0（与 ExoPlayer/KissFFT/vDSP 兼容），作为仓库唯一 License。
- 更新项：`LICENSE` 文件替换，`README`/`pubspec`/`build.gradle`/`podspec` 声明，移除 GPL 相关引用；生成 NOTICE/DEPENDENCIES（列出 ExoPlayer Apache、KissFFT BSD、vDSP 专有）并纳入 CI 校验。

## 4. 工作拆解（建议顺序）
1) 移除 FFmpeg 依赖：清理 `ffmpeg/` 预编库、CMake/Gradle/Podspec 引用、解码代码路径；更新 README/CHANGELOG。
2) 平台解码回归：验证本地/HTTP 源播放与 PCM 推送；补充弱网/seek 基本测试。
3) FFT 替换：Android 接入 JNI + KissFFT，删除 Kotlin FFT 主路径；iOS 默认 vDSP + 可选 KissFFT，参数与归一化对齐；新增跨端交叉校验测试。
4) 组件化拆分：抽取可视化管线为独立模块（Android AAR：`com.soundwave:visualization-core`；iOS Pod/SPM：`SoundwaveVisualization`；Dart 包：`soundwave_visualization`），并新增“数据导出”可选模块（WAV/CSV/JSON 输出）；调整插件引用路径，补发布配置（groupId/version/pom/Podspec/SPM）。
5) License 切换：替换 LICENSE 文件与声明，生成 NOTICE/DEPENDENCIES，检查依赖许可，更新 README/CHANGELOG。
6) 回归与基线：跑通 `flutter analyze`、`flutter test`、新增 FFT 对齐测试（Android JNI vs iOS vDSP vs iOS KissFFT 参考），长时间播放 smoke；新增数据导出正确性（PC 复核）与可视化后门开关验证。

## 5. 测试与验收
- 单元测试：FFT 频点正确性（单频/双频/白噪），窗口与 nfft/overlap 参数覆盖；PCM 节流与序号递增。
- 集成测试：本地/HTTP 播放、seek 后 PCM/FFT 序列重置；前后台切换恢复；跨端谱对齐（vDSP vs KissFFT）。
- 性能基线：FFT 抽稀后 CPU 峰值（Android/iOS）不回归；帧率目标 60fps（或自适应降级）；长稳播放（≥1h）无序列漂移。
- 许可证检查：依赖 License 列表与新 License 匹配；仓库不再包含 GPL 组件。

## 6. 风险与缓解
- 弱网/流式在平台解码路径下的稳定性：增加重试与缓冲事件观测。
- JNI 接口稳定性：保持简单签名与版本号，附兼容测试。
- 组件拆分后的依赖地狱：明确版本约束与兼容矩阵，示例锁定同版本。
- License 变更遗漏：用脚本检查 GPL 片段，人工复核 README/构建脚本。

## 7. 迁移与兼容性
- 格式支持变化：移除 FFmpeg 后仅支持平台解码格式（mp3/aac/wav/alac/flac*，以平台支持为准）；不再支持 FFmpeg 专有/长尾格式（如 ape/opus/ogg 需另行确认），文档需列出支持/不支持矩阵。
- 配置变更：统一输出 44.1 kHz/float32，若调用方依赖源采样率需调整；FFT Downmix 为默认行为，需在发布说明中提示。
- API 兼容：保持 MethodChannel/事件字段不变；新增 iOS FFT 后端切换参数需有默认值（vDSP），向后兼容。

## 8. 里程碑与交付
- M1：移除 FFmpeg + 平台解码回归通过。
- M2：FFT 替换完成（Android KissFFT JNI / iOS vDSP），对齐测试通过。
- M3：可视化管线拆分并发布 AAR + Dart 包，插件接入新包。
- M4：License 切换完成，文档/CHANGELOG 更新，端到端测试通过。
