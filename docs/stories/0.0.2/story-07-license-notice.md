# Story 07：许可证切换与合规检查

## 目标
- 确认仓库切换至 Apache 2.0 后的合规性，补全第三方 LICENSE/NOTICE 摘录（含 KissFFT/ExoPlayer/Apple 条款），并在 CI/检查脚本中固化。

## 测试优先（TDD）
- ✅ [1] License 扫描：脚本/CI 运行通过，无 GPL/FFmpeg 残留。
- ✅ [2] NOTICE/DEPENDENCIES 校验：包含所有第三方依赖条目，格式正确。

## 开发任务
- ✅ [3] 审核依赖清单，完善 LICENSE/NOTICE/DEPENDENCIES。
- ✖️ [4] 更新 README/设计/PRD 中的许可声明，说明平台依赖许可。
- ✖️ [5] 增加合规检查脚本/CI 步骤。

## 完成标准（DoD）
- ✅ [6] License 扫描与 CI 通过，无违规依赖。
- ✖️ [7] 文档与声明更新到位，可追溯第三方许可。 
