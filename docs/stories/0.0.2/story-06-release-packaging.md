# Story 06：组件化发布与版本对齐

## 目标
- 发布 Android AAR（`com.soundwave:visualization-core`）、iOS Pod/SPM（`SoundwaveVisualization`）、Dart 包（`soundwave_visualization`），版本 semver 对齐，可二进制/源码依赖。

## 测试优先（TDD）
- ✅ [1] 发布验收：本地/CI 打包 AAR/XCFramework/pub 包并验证示例可用。（新增 `tools/release/build_release.sh` 一键构建 AAR/XCFramework 与 pub dry-run，产物输出至 `build/release/`）
- ✖️ [2] 门禁：构建/格式/单测通过，CI 发布流程（dry-run）通过。

## 开发任务
- ✖️ [3] 配置 Maven 发布（groupId/artifactId/version/pom 元数据）。
- ✖️ [4] 配置 CocoaPods/SwiftPM 包（名称、版本、binary/源码双形态）。
- ✖️ [5] 配置 Dart pubspec/发布脚本；示例锁版本，文档补充接入方式。

## 完成标准（DoD）
- ✖️ [6] 发布产物可用（本地或内测仓库验证）。
- ✖️ [7] CI 发布流程可重复（含 dry-run），构建/测试门禁通过。
- ✖️ [8] 文档更新接入指引与版本矩阵。***
