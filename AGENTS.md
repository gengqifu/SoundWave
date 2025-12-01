# AGENTS 设计

本文将项目按多代理协作的思路拆解，将 Flutter、C/C++ 层、音频处理和 DevOps 等责任清晰分配，便于并行推进和后续交接。

## 1. 项目目标
- 在 iOS/Android 上实现音频播放与实时可视化（时域波形与频域谱）。
- 播放本地/流式音频，解码为 PCM，做实时处理与渲染。
- 保持低延迟、稳定帧率，并提供可测试、可扩展的架构。

## 2. 代理角色与职责
- **Product/UX Agent**：定义核心场景（本地文件、流式播放）、交互（缩放、拖动、播放控制）、性能目标（帧率/延迟）、视觉规格（主题、波形样式）。
- **Flutter UI Agent**：实现界面、状态管理（如 Riverpod/Provider/BLoC 任选其一）、动画与触控交互；桥接原生插件接口；绘制定制 Waveform/FFT 组件。
- **Flutter Plugin Agent**：定义 `MethodChannel`/`PlatformChannel` 接口；封装原生 C++/平台端能力为 Flutter 插件；提供参数校验和错误映射。
- **Audio Core (C/C++) Agent**：负责音频解码（优先 FFmpeg，平台解码器作为降级）、重采样、缓冲、PCM 队列；实现时域/频域处理（窗口化、FFT，默认 KissFFT）；提供零拷贝/低拷贝数据面向 UI 层。
- **Threading/Performance Agent**：设计音频回调/渲染线程模型，避免主线程阻塞；锁策略、环形缓冲、内存复用；定义延迟与吞吐监控点。
- **QA/Testing Agent**：牵头 TDD，用例先行；制定测试矩阵（端到端播放、丢包/弱网、长时间运行、前后台切换）；音质与性能基准（XRuns、延迟、CPU/GPU、内存）；落地 CI 自动化脚本与覆盖率目标。
- **DevOps Agent**：CI 配置（格式化、静态检查、单测、集成测）；构建产物分发；依赖管理与缓存（Flutter/CMake/FFmpeg 预编译包）；环境维护（Flutter SDK 路径/权限、可写 HOME 目录、Android SDK/NDK/CMake 版本一致性）。

## 3. TDD 开发准则
- 用例先行：每个功能/缺陷先编写失败的单测/集成测，再实现代码使之通过。
- 分层测试：
  - Dart 层：状态管理、UI 组件的绘制/交互逻辑单测（可使用 Golden/Widget Test）。
  - 插件交互：MethodChannel 接口契约测试、错误映射测试。
  - C/C++ 核心：DSP/FFT 结果、缓冲读写、线程模型的单元/集成测试（可基于 gtest）。
- 验收准则：PR 合并前需本地通过全部相关测试与 `flutter analyze`/`clang-tidy`；CI 作为强制门禁。
- 回归策略：新增功能需补充对应回归用例，避免仅手动验证。

## 4. 子系统与接口
- **Flutter UI 层**
  - WaveformView：时域绘制（可窗口滑动/缩放）；数据输入为分帧 PCM（float）。
  - SpectrumView：频域绘制（实时 FFT 结果，幅度/功率谱）。
  - PlayerControls：播放/暂停/跳转/加载状态。
  - State 管理：暴露 `AudioState{position,duration,isPlaying,levels,spectrum}`。
- **插件接口（建议 Platform Channel 定义）**
  - `init(config)`: 设备参数/缓冲尺寸/采样率。
  - `load(source)`: 本地路径 / URL。
  - `play() / pause() / stop() / seek(ms)`.
  - `onPcmFrame(float[] samples)`: 向 Dart 推送分帧数据（多通道时约定交错/平面格式）。
  - `onSpectrum(float[] spectrum)`: 频域结果（与窗口大小/重叠度配套的 meta）。
  - `onState(event)`: 缓冲、错误、完成。
- **C/C++ 音频核心**
  - 解码：FFmpeg 为默认后端输出统一的 PCM（float32/16bit 可配置），平台解码器为备选。
  - 缓冲：环形缓冲 + 双缓冲输出，保证实时性。
  - DSP：窗口化 (Hann/Hamming)，FFT（默认 KissFFT），峰值/均方能量。
  - 时钟：以音频回放时钟驱动 UI 更新时间，确保同步。

## 5. 数据流与线程模型
- 解码线程：读取源 → 解码 → 重采样 → 写入环形缓冲。
- 音频回放线程：从缓冲拉取 PCM → 播放 → 同步回调位置 → 可选旁路分支发送 UI 分帧数据。
- FFT 线程（可与回放同线程或独立）：对分帧数据执行 FFT → 结果推送给 Flutter。
- UI 线程：接收波形/谱数据 → 绘制；与控制指令（play/pause/seek）经 Channel 下发。

## 6. 工具与依赖建议
- Flutter 3.x（最新稳定）。
- 插件模板使用 `flutter create --org ... --template=plugin soundwave_player`。
- CMake 构建 C++ 核心；引入 FFmpeg 预编译静态库（iOS/Android，arm64/armv7/x86_64），配置头文件与链接路径；必要时 fallback 平台 `AVAudioEngine` / `MediaCodec`。
- FFT：KissFFT（轻量）。
- 测试：`flutter test`、自定义集成测试（integration_test），profile 构建收集性能。

## 7. 质量与性能目标
- 延迟：解码→播放端到端 < 120ms，UI 显示延迟 < 200ms。
- 音频稳定性：无明显 XRuns/Drop；长时间播放内存稳定。
- 帧率：波形/谱绘制 60fps（或设备性能自适应降级）。
- 代码质量：格式化（`flutter format`/`clang-format`），静态检查（`flutter analyze`/`clang-tidy`）。

## 8. 交付里程碑（示例）
- M1：插件骨架 + 基础播放（本地文件），时域波形静态绘制。
- M2：流式播放 + 实时时域波形（分帧推送）。
- M3：频域谱 + 交互（缩放/拖动/seek）+ 性能调优。
- M4：弱网/长时间稳定性测试 + CI/分发流程。

## 9. 风险与缓解
- 移动端编译 FFmpeg 复杂：预编译二进制 + CMake cache；CI 提供下载/校验脚本；必要时选择平台解码器。
- 跨线程同步/锁竞争：环形缓冲 + 无锁队列；避免在回放回调做重计算，FFT 可在独立线程。
- 数据量大导致 UI 卡顿：分帧限速、抽稀；用 `ui.Image`/`CustomPainter` 批量绘制，避免逐点绘制。

## 10. 沟通规范
- 默认使用中文回答问题，保持与项目文档语言一致。
- 提交信息（commit message）统一使用中文，便于团队审阅与追踪。
- 每个任务完成后：自动更新 Story 状态（勾选）、提交代码并推送，保持待办与代码同步。
