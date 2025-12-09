# Story 01：移除 FFmpeg 依赖与清理构建

## 目标
- 移除 Android/iOS 所有 FFmpeg 代码、二进制与构建引用，切换仓库许可证为 Apache 2.0 并补充第三方 LICENSE/NOTICE 摘录，确保平台解码路径成为唯一入口。

## 测试优先（TDD）
- ✖️ [1] 构建清理验证：无 FFmpeg 相关 CMake/Gradle/Pod 目标，构建脚本检查无残留。
- ✖️ [2] 许可证检查：新增/更新 LICENSE、NOTICE/DEPENDENCIES，包含 KissFFT 等依赖；CI/脚本扫描无 GPL 片段。

## 开发任务
- ✖️ [3] 删除 FFmpeg 相关源码、预编译库、脚本，清理 CMake/Gradle/Podspec 引用。
- ✖️ [4] 更新文档（README/CHANGELOG/PRD/设计/计划中涉及的解码描述）确认平台解码为唯一方案。
- ✖️ [5] 替换主 LICENSE 为 Apache 2.0，新增 NOTICE/DEPENDENCIES，记录第三方许可。

## 完成标准（DoD）
- ✖️ [6] 构建脚本不再引用 FFmpeg，相关文件被移除，许可证文件更新完整。
- ✖️ [7] 文档同步更新（README/设计/计划），无 FFmpeg 描述残留。
- ✖️ [8] 执行许可证/构建检查，确认无 GPL/GPLv3 依赖残留。 
