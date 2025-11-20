# Story 13：覆盖率与 CI 门禁

## 目标
配置 CI 流程运行 `flutter analyze/test`、C++ gtest、格式化检查，生成覆盖率报告并设定阈值，作为合并门禁。

## 测试优先（TDD）
- 先编写 CI 流程的验证用例：人为降低覆盖率触发失败，格式化失败触发失败。
- 本地脚本模拟 CI 关键步骤，确保可复现。

## 开发任务
- CI 配置（GitHub Actions 等）：Flutter analyze/test、CMake+gtest、clang-format/dart format 检查。
- 覆盖率收集：Dart 覆盖率、C++ 覆盖率（lcov/llvm-cov），合并报告（可选）。
- 阈值：设定最低覆盖率，未达则失败；构建缓存优化。

## 完成标准（DoD）
- CI 绿，失败条件验证通过。
- 覆盖率报告产出，可下载/查看。
- 文档：CI 使用说明、覆盖率阈值政策。
