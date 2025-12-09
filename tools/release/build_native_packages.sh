#!/usr/bin/env bash
set -euo pipefail

# 构建/校验纯原生发布包（无 Flutter 依赖）
# - Android：发布 AAR 到本地 maven 仓库
# - iOS：校验 Podspec/SPM（要求先产出 SoundwaveVisualization.xcframework）
#
# 用法：
#   ./tools/release/build_native_packages.sh
# 输出：
#   build/native-release/{android,ios}/

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_DIR="$ROOT_DIR/native/android-visualization"
IOS_DIR="$ROOT_DIR/native/ios-visualization"
OUT_DIR="$ROOT_DIR/build/native-release"
ANDROID_OUT="$OUT_DIR/android"
IOS_OUT="$OUT_DIR/ios"

mkdir -p "$ANDROID_OUT" "$IOS_OUT"

echo "==> Android: publish native AAR (no Flutter deps)"
# 优先使用项目内 wrapper，避免依赖全局 gradle
GRADLE_BIN="$ROOT_DIR/soundwave_player/android/gradlew"
if [[ ! -x "$GRADLE_BIN" ]]; then
  if command -v gradle >/dev/null 2>&1; then
    GRADLE_BIN="gradle"
  else
    echo "Gradle wrapper 未找到，且系统未安装 gradle。请安装后重试。" >&2
    exit 1
  fi
fi

"$GRADLE_BIN" -p "$ANDROID_DIR" \
  clean publishReleasePublicationToLocalRepository \
  -PsoundwaveRepoDir="$ANDROID_OUT/m2-local"

echo "==> iOS: lint Podspec / SPM（需已有 XCFramework）"
XCFRAMEWORK="$IOS_DIR/SoundwaveVisualization.xcframework"
if [[ ! -d "$XCFRAMEWORK" ]]; then
  echo "缺少 $XCFRAMEWORK，请先产出 XCFramework（xcodebuild -create-xcframework ...）。" >&2
  exit 1
fi

if command -v pod >/dev/null 2>&1; then
  pod lib lint "$IOS_DIR/SoundwaveVisualization.podspec" \
    --allow-warnings --skip-tests --fail-fast
else
  echo "CocoaPods 未安装，跳过 pod lib lint。" >&2
fi

if command -v swift >/dev/null 2>&1; then
  swift package diagnose --manifest-path "$IOS_DIR/Package.swift"
else
  echo "Swift 工具链未安装，跳过 SwiftPM 校验。" >&2
fi

echo "==> Done. Artifacts/校验输出位于 $OUT_DIR"
