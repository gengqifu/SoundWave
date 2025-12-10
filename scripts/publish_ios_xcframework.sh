#!/usr/bin/env bash
set -euo pipefail

# 打包 iOS XCFramework 为 zip，并生成 sha256 清单，便于后续发放/SPM 校验。
# 环境变量：
#   VERSION   版本号（默认 0.0.2-local）
#   OUTPUT    输出目录（默认 $ROOT/build/ios-dist）
#   PROFILE   使用的构建目录（默认 Release）

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.0.2-local}"
PROFILE="${PROFILE:-Release}"
SRC="$ROOT/soundwave_player/build/ios_framework/$PROFILE"
OUTPUT="${OUTPUT:-$ROOT/build/ios-dist}"

if [[ ! -d "$SRC" ]]; then
  echo "!! XCFramework 未找到：$SRC" >&2
  echo "   请先执行 flutter build ios-framework --xcframework --output=soundwave_player/build/ios_framework" >&2
  exit 1
fi

mkdir -p "$OUTPUT"
CHECKSUM_FILE="$OUTPUT/checksums-${VERSION}.txt"
: > "$CHECKSUM_FILE"

for name in SoundwaveCore soundwave_player; do
  src_path="$SRC/${name}.xcframework"
  if [[ ! -d "$src_path" ]]; then
    echo "-- 跳过 $name（未找到 $src_path）"
    continue
  fi
  zip_path="$OUTPUT/${name}-${VERSION}.zip"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$src_path" "$zip_path"
  shasum -a 256 "$zip_path" >> "$CHECKSUM_FILE"
  echo "  -> 打包 $zip_path"
done

echo "完成。输出目录：$OUTPUT"
echo "校验清单：$CHECKSUM_FILE"
