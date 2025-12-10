# Story 06：AAR/XCFramework 构建与发布准备

## 目标
- 产出可发布的 Android AAR（Maven）与 iOS XCFramework，支持源码/二进制双模式集成，准备发布脚本与文档。

## 测试优先（TDD）
- ✖️ [1] 构建测试：AAR/XCFramework 本地构建脚本执行成功，产物包含核心符号与所需资源。
- ✖️ [2] 集成测试：新建最小宿主项目分别引用 AAR/XCFramework，验证 PCM push/波形/频谱事件通路。
- ✖️ [3] 发布脚本检查：Maven/本地私有仓库推送、XCFramework 打包脚本可执行。
- ✅ [4] 频域测试（Android）：FFT 精度/性能、spectrum 事件桥接单测/集成测通过。
- ✅ [5] 频域测试（iOS）：FFT 精度/性能、spectrum 事件桥接单测/集成测通过。

## 开发任务
- ✅ [6] 拆分独立原生 SDK 模块（Android）：核心实现独立于 Flutter 插件，插件仅作为壳层依赖 SDK，并迁移现有核心代码；拆分和迁移后不影响功能，现有测试全部通过。
- ✅ [7] 拆分独立原生 SDK 模块（iOS）：核心实现独立于 Flutter 插件，插件仅作为壳层依赖 SDK，并迁移现有核心代码；拆分和迁移后不影响功能，现有测试全部通过。
- ✅ [8] Android 频域处理：在 core 集成 KissFFT，完成窗口化/FFT 计算，adapter 仅做 PCM 接入，桥接 spectrum 事件到 Flutter。
- ✅ [9] iOS 频域处理：在 core 集成 KissFFT（与 Android 统一），完成窗口化/FFT 计算，tap 层仅推送 PCM，桥接 spectrum 事件到 Flutter。
- ✅ [10] Android 构建：Gradle/CMake 配置输出 AAR，处理 ABI/符号、版本号、POM 元数据。
- ✖️ [11] iOS 构建：Xcode/CMake 生成 XCFramework（静态/动态选择），准备 SPM/Pod 集成说明。
- ✖️ [12] 发布与文档：编写发布脚本与 README/接入说明，包含版本/依赖/示例。

## 完成标准（DoD）
- ✖️ [13] 构建与宿主集成验证通过，核心 API/事件可用。
- ✖️ [14] 发布脚本与文档齐全，版本号/依赖声明清晰。 
