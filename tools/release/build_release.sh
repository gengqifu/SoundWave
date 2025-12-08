#!/usr/bin/env bash
set -euo pipefail

# 统一构建发布产物（Android AAR、iOS XCFramework、Dart 包 dry-run）。
# 依赖：已安装 Flutter SDK、Android SDK/NDK、Xcode。
#
# 用法：
#   ./tools/release/build_release.sh
# 生成产物位于 build/release/{android,ios,dart}/

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_DIR="$ROOT_DIR/soundwave_player"
OUT_DIR="$ROOT_DIR/build/release"
ANDROID_OUT="$OUT_DIR/android"
IOS_OUT="$OUT_DIR/ios"
DART_OUT="$OUT_DIR/dart"

mkdir -p "$ANDROID_OUT" "$IOS_OUT" "$DART_OUT"

echo "==> Building Android AAR"
(
  cd "$PLUGIN_DIR"
  flutter build aar \
    --no-debug \
    --no-profile \
    --target-platform android-arm,android-arm64,android-x64 \
    --build-number 1 \
    --build-name 0.0.2 \
    --output-dir "$ANDROID_OUT"
)

echo "==> Building iOS XCFramework"
(
  cd "$PLUGIN_DIR"
  flutter build ios-framework \
    --no-debug \
    --no-profile \
    --xcframework \
    --output="$IOS_OUT"
)

echo "==> Copying license/notice to artifacts"
cp "$ROOT_DIR/NOTICE" "$ANDROID_OUT/" 2>/dev/null || true
cp "$ROOT_DIR/DEPENDENCIES" "$ANDROID_OUT/" 2>/dev/null || true
cp "$PLUGIN_DIR/NOTICE" "$IOS_OUT/" 2>/dev/null || true
cp "$PLUGIN_DIR/DEPENDENCIES" "$IOS_OUT/" 2>/dev/null || true

echo "==> Dart package dry-run publish"
(
  cd "$PLUGIN_DIR"
  flutter pub publish --dry-run >"$DART_OUT/pub_dry_run.log"
)

echo "==> Done. Artifacts under $OUT_DIR"
