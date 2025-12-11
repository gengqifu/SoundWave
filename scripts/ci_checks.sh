#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[ci] license scan..."
./scripts/check_license.sh

echo "[ci] notice/dependencies check..."
./scripts/check_notice.sh

echo "[ci] DONE."
