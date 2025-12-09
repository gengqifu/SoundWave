# Story 08：原生包集成 Demo 跑通

## 目标
- 在 Android/iOS 上运行可用的 Demo，依赖纯原生包（AAR/XCFramework，无 Flutter 依赖），实现播放/波形/频谱/导出基础流程。
- 验证本地 path（调试）与发布产物（maven/Pod/SPM）两种依赖方式均可构建运行。

## 测试优先（TDD）
- ✖️ [1] 集成冒烟：Android Demo 依赖本地原生模块/本地 m2 AAR 可运行；iOS Demo 依赖本地 XCFramework/Pod 可运行。
- ✖️ [2] 发布验收：Android Demo 切换到 maven 发布产物，iOS Demo 切换到 Pod/SPM 发布产物，均可构建运行（可使用内测仓库或本地发布目录）。

## 开发任务
- ✖️ [3] Android Demo 接入：调整插件/示例依赖纯原生 AAR，补充最小原生示例或 Flutter 示例配置切换。
- ✖️ [4] iOS Demo 接入：Podfile/SwiftPM 引用 XCFramework，示例跑通播放/回调/导出。
- ✖️ [5] 自动化脚本：在 `tools/release` 增加 Demo 集成构建/运行（或 smoke）步骤，支持本地与发布依赖切换。

## 完成标准（DoD）
- ✖️ [6] Android/iOS Demo 均可构建运行，基础功能验证通过（播放/波形/谱/导出）。
- ✖️ [7] Demo 支持调试（本地原生模块）与发布（maven/Pod/SPM）两种依赖模式，切换方式有文档说明。***
