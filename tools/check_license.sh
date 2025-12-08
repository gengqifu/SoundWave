#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

error() {
  echo "ERROR: $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || error "Missing required file: $path"
}

echo "==> Checking required license files"
require_file "LICENSE"
require_file "NOTICE"
require_file "DEPENDENCIES"

echo "==> Ensuring DEPENDENCIES contains key entries"
grep -qi "ExoPlayer" DEPENDENCIES || error "DEPENDENCIES missing ExoPlayer entry"
grep -qi "KissFFT" DEPENDENCIES || error "DEPENDENCIES missing KissFFT entry"
grep -qi "vDSP" DEPENDENCIES || error "DEPENDENCIES missing vDSP entry"

echo "==> Scanning for GPL or forbidden licenses"
# Simple grep for common GPL markers; ignore VCS/build outputs.
if rg -i "gnu general public license|gpl-2\\.0|gpl-3\\.0" --hidden --iglob '!.git' --iglob '!build' --iglob '!.*cache' .; then
  error "Found potential GPL references; please remove or update dependencies"
fi

echo "==> License check passed"
