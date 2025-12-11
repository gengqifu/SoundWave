#!/usr/bin/env bash
set -euo pipefail

# 校验 NOTICE 与 DEPENDENCIES 是否包含关键第三方条目，避免遗漏。

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REQ_NOTICE=(
  "Flutter"
  "Media3"
  "ExoPlayer"
  "KissFFT"
  "Apple Inc."
)

REQ_DEPS=(
  "Flutter SDK"
  "meta (BSD-3-Clause)"
  "flutter_lints"
  "KissFFT"
  "media3-exoplayer"
  "media3-ui"
  "androidx.core:core-ktx"
  "androidx.appcompat"
  "material 1.12"
  "Kotlin stdlib"
  "AVFoundation"
)

check_contains() {
  local file="$1"; shift
  local missing=()
  while IFS= read -r token; do
    if ! grep -q "${token}" "$file"; then
      missing+=("$token")
    fi
  done < <(printf '%s\n' "$@")

  if ((${#missing[@]} > 0)); then
    echo "[check_notice] $file missing entries: ${missing[*]}" >&2
    return 1
  fi
}

check_contains "$ROOT/NOTICE" "${REQ_NOTICE[@]}"
check_contains "$ROOT/DEPENDENCIES" "${REQ_DEPS[@]}"

echo "[check_notice] OK: NOTICE and DEPENDENCIES contain required entries."
