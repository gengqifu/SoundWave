#!/usr/bin/env bash
set -euo pipefail

# 简易本地播放性能采集脚本（Flutter profile 模式）。
# 依赖：已安装 flutter，且有可访问的本地音频文件。

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE_DIR="$APP_ROOT/example"
PROFILE_OUT="${PROFILE_OUT:-$APP_ROOT/profile/local_playback.profile.json}"
SOURCE_URL="${SOURCE_URL:-file:///tmp/sample.mp3}"

echo "==> Building example app in profile mode..."
pushd "$EXAMPLE_DIR" >/dev/null
flutter build apk --profile

echo "==> Installing and running with Observatory tracing..."
flutter run --profile -d emulator-5554 \
  --trace-startup \
  --trace-skia \
  --trace-systrace \
  --trace-allowlist="embedder,io,framework" \
  --route="/" \
  --dart-define=SOUNDWAVE_SAMPLE_URL="$SOURCE_URL" \
  --write-sksl-on-exit "$PROFILE_OUT"
popd >/dev/null

echo "Profile trace written to $PROFILE_OUT"
