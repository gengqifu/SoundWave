# Story 13：覆盖率与 CI 门禁

## 目标
配置 CI 流程运行 `flutter analyze/test`、C++ gtest、格式化检查，生成覆盖率报告并设定阈值，作为合并门禁。当前聚焦本地播放相关代码，Story10 流式用例暂跳过或标记允许失败。

## 测试优先（TDD）
- ✔ [1] 先编写 CI 流程的验证用例：人为降低覆盖率触发失败，格式化失败触发失败（本地脚本/Make 目标模拟，见 `scripts/ci_fail_format.sh`）。
- ✔ [2] 本地脚本模拟 CI 关键步骤，确保可复现（`flutter analyze/test`、native `ctest`；提供一键脚本 `scripts/ci_local.sh`）。

## 开发任务
- ✔ [3] CI 配置（GitHub Actions）：Flutter analyze/test（跳过 Story10 流式用例）、CMake+gtest、clang-format/dart format 检查，缓存 Flutter/.pub-cache/CMake（见 `.github/workflows/ci.yaml`）。
- ✔ [4] 覆盖率收集：Dart 覆盖率（lcov，见 `scripts/ci_coverage.sh`），C++ 覆盖率（lcov/llvm-cov 占位，CI 先允许失败），可选合并报告；先设置阈值占位（如 Dart ≥60%，C++ 暂允许失败）。
- ✔ [5] 阈值：设定最低覆盖率（先占位 Dart ≥60%，C++ 暂允许失败），未达则失败；构建缓存优化（Flutter/.pub-cache/CMake 缓存已启用）。

## 完成标准（DoD）
- ✖ [6] CI 绿，失败条件验证通过（本地或手动触发）。
- ✖ [7] 覆盖率报告产出，可下载/查看。
- ✖ [8] 文档：CI 使用说明、覆盖率阈值政策、跳过/允许失败的用例说明。
