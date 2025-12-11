#!/usr/bin/env bash
set -euo pipefail

# 回归：PCM/FFT 管线集成测试（native/core）
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/native/core/build"

if [[ ! -d "$BUILD_DIR" ]]; then
  echo "[regress-pcm-fft] build dir missing: $BUILD_DIR"
  echo "请先在 native/core 运行 cmake/make 构建测试目标。"
  exit 1
fi

cd "$BUILD_DIR"
echo "[regress-pcm-fft] running ctest in $BUILD_DIR"
ctest --output-on-failure
