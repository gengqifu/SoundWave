# Story 05：License 切换与合规

## 目标
- 仓库统一使用 Apache-2.0，生成 NOTICE/DEPENDENCIES，覆盖 ExoPlayer Apache、KissFFT BSD、vDSP 专有，移除 GPL 残留。

## 测试优先（TDD）
- ✅ [1] 合规检查：脚本或 CI 检查确保无 GPL 残留，NOTICE/DEPENDENCIES 含关键依赖。（新增 `tools/check_license.sh`，生成 NOTICE/DEPENDENCIES）
- ✅ [2] 门禁：构建/测试通过（保证 License 变更不破坏构建流程）。(`flutter analyze`、`flutter test` 全量通过)

## 开发任务
- ✅ [3] 替换 LICENSE 文件，新增 NOTICE/DEPENDENCIES 生成流程（脚本/Gradle/Podspec）。(LICENSE 已换为 Apache-2.0；新增 NOTICE/DEPENDENCIES 与 `tools/check_license.sh`)
- ✅ [4] 更新 README/文档中的 License 声明。（README 新增 License 章节，引用 Apache-2.0 与第三方依赖 NOTICE/DEPENDENCIES）
- ✅ [5] CI 增加 License 合规检查 Job：在 PR 阶段运行统一脚本（本地可复用），校验 LICENSE/NOTICE/DEPENDENCIES 存在且包含关键依赖（ExoPlayer Apache、KissFFT BSD、vDSP 专有），扫描仓库无 GPL 残留，失败阻断合并。（GitHub Actions `ci.yaml` 新增 `tools/check_license.sh` 步骤）

## 完成标准（DoD）
- ✅ [6] 合规检查通过，仓库无 GPL 文件/引用。（`tools/check_license.sh` 已通过，LICENSE/NOTICE/DEPENDENCIES 就绪）
- ✅ [7] NOTICE/DEPENDENCIES 覆盖关键依赖并纳入发布流程。（根目录及 `soundwave_player/` 内均包含 NOTICE/DEPENDENCIES，随插件发布可见）
- ✖️ [8] 文档更新完成，构建/测试门禁通过。***
