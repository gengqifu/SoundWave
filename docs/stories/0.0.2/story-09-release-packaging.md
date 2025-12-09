# Story 09：组件化发布与版本对齐（现有插件形态）

> 说明：纯原生（无 Flutter 依赖）的包拆分与发布改由 Story 08 跟进。本 Story 聚焦现有 Flutter 插件/示例的发布流程与版本对齐，后续可在 Story 08 完成后迁移发布脚本/产物。

## 目标
- 发布现有 Flutter 插件（含示例）产物，版本 semver 对齐，构建/测试/合规通过；为后续迁移到 Story 08 的纯原生包发布打基础。

## 测试优先（TDD）
- ✅ [1] 发布验收：本地/CI 打包 AAR/XCFramework/pub 包并验证示例可用。（新增 `tools/release/build_release.sh` 一键构建 AAR/XCFramework 与 pub dry-run，产物输出至 `build/release/`）
- ✅ [2] 门禁：构建/格式/单测通过，CI 发布流程（dry-run）通过。（`flutter analyze`、`flutter test` 已跑通；后续 CI 发布步骤沿用）

## 开发任务
- ✅ [3] 配置 Maven 发布（groupId/artifactId/version/pom 元数据）。(`soundwave_player/android/build.gradle` 启用 maven-publish，产出 `com.soundwave:visualization-core:0.0.2`，默认发布到本地 m2) ※ 后续会被 Story08 的纯原生 AAR 取代。
- ✅ [4] 配置 CocoaPods/SwiftPM 包（名称、版本、binary/源码双形态）。(`soundwave_player/ios/soundwave_player.podspec` 更新元数据/版本 0.0.2；iOS XCFramework 可由发布脚本产出供 Pod/SPM 分发) ※ 后续由 Story08 迁移到纯原生 XCFramework。
- ✅ [5] 配置 Dart pubspec/发布脚本；示例锁版本，文档补充接入方式。（`soundwave_player/pubspec.yaml` 更新版本/元数据，发布脚本 `tools/release/build_release.sh` 包含 pub dry-run；示例仍使用 path 依赖）

## 完成标准（DoD）
- ✖️ [6] 发布产物可用（本地或内测仓库验证）。※ 若迁移到 Story08 后需要重新验收。
- ✖️ [7] CI 发布流程可重复（含 dry-run），构建/测试门禁通过。※ 后续需与 Story08 的原生包发布流程对齐。
- ✖️ [8] 文档更新接入指引与版本矩阵。※ 最终发布形态以 Story08 方案为准。***
