#!/usr/bin/env bash
set -euo pipefail

# 本地模拟 CI 关键步骤：
# - Flutter analyze
# - 格式检查（dart format --set-exit-if-changed）
# - Flutter test（流式用例已标记跳过或允许失败）
# - native/core gtest（若 build 目录已配置）

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_OVERRIDE="${HOME_OVERRIDE:-$HOME}"

echo "==> Flutter analyze"
pushd "$ROOT" >/dev/null
HOME="$HOME_OVERRIDE" flutter analyze

echo "==> Dart format check"
HOME="$HOME_OVERRIDE" dart format --output=none --set-exit-if-changed lib test

echo "==> Flutter test"
HOME="$HOME_OVERRIDE" flutter test

echo "==> Native gtest (if build exists)"
if [ -d "$ROOT/native/core/build" ]; then
  pushd "$ROOT/native/core" >/dev/null
  cmake --build build
  ctest --test-dir build -R audio_core_tests
  popd >/dev/null
else
  echo "native/core/build not found, skipping native tests"
fi

popd >/dev/null
echo "CI local run completed."
