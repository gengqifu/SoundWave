#!/usr/bin/env bash
set -euo pipefail

# 收集 Dart 覆盖率，生成 lcov/html 报告。

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_OVERRIDE="${HOME_OVERRIDE:-$HOME}"

pushd "$ROOT/soundwave_player" >/dev/null
HOME="$HOME_OVERRIDE" flutter test --coverage
genhtml coverage/lcov.info -o coverage/html || true
echo "Dart coverage written to coverage/lcov.info (html in coverage/html)"
popd >/dev/null
