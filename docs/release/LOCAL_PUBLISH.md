## 本地发布脚本（Android / iOS）

### Android AAR -> 本地 Maven 目录
脚本：`scripts/publish_android_local.sh`

- 默认使用本地 Gradle 8.1.1 分发，可通过 `GRADLE_BIN` 覆盖。
- 版本号通过环境变量 `VERSION` 指定，默认 `0.0.2-local`。
- 输出目录通过 `REPO_DIR` 控制，默认 `build/maven-repo`。
- 脚本会先执行 `assembleRelease`，然后将 core / adapter / soundwave_player 的 AAR 和 POM 写入本地 Maven 结构。

示例：
```bash
VERSION=0.0.2-local ./scripts/publish_android_local.sh
# Gradle 自定义路径
GRADLE_BIN=~/apps/gradle-8.1.1/bin/gradle ./scripts/publish_android_local.sh
```

### iOS XCFramework 打包
脚本：`scripts/publish_ios_xcframework.sh`

- 依赖已构建的 `soundwave_player/build/ios_framework/<Profile>/` 目录（可通过 `PROFILE` 指定，默认 Release）。
- 版本号 `VERSION`，输出目录 `OUTPUT`（默认 `build/ios-dist`）。
- 会对 `SoundwaveCore.xcframework` 与 `soundwave_player.xcframework` 生成 zip，并写入 sha256 清单。

示例：
```bash
VERSION=0.0.2-local PROFILE=Release ./scripts/publish_ios_xcframework.sh
```
