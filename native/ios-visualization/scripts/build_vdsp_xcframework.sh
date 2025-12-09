#!/usr/bin/env bash
set -euo pipefail

# 基于 vDSP 的合成闭环生成 SoundwaveVisualization.xcframework（设备+模拟器）
# 依赖：Xcode/clang，Accelerate
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/build"
XC_OUT="$OUT_DIR/SoundwaveVisualization.xcframework"

SRC_DIR="$ROOT_DIR/Stub"
HEADERS_DIR="$OUT_DIR/include"
ARCHIVE_IOS="$OUT_DIR/ios"
ARCHIVE_SIM="$OUT_DIR/sim"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR" "$ARCHIVE_IOS" "$ARCHIVE_SIM" "$HEADERS_DIR"
# 只拷贝头文件，避免源码混入产物
cp "$SRC_DIR/SWVisVDSP.h" "$HEADERS_DIR/"

echo "==> Build device static lib"
xcrun clang -fobjc-arc -isysroot "$(xcrun --sdk iphoneos --show-sdk-path)" \
  -fembed-bitcode -arch arm64 \
  -I"$SRC_DIR" \
  -framework Accelerate \
  -c "$SRC_DIR/SWVisVDSP.m" -o "$ARCHIVE_IOS/SWVisVDSP.o"
libtool -static -o "$ARCHIVE_IOS/libswvis.a" "$ARCHIVE_IOS/SWVisVDSP.o"

echo "==> Build simulator static lib"
xcrun clang -fobjc-arc -isysroot "$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -fembed-bitcode -arch arm64 \
  -I"$SRC_DIR" \
  -framework Accelerate \
  -c "$SRC_DIR/SWVisVDSP.m" -o "$ARCHIVE_SIM/SWVisVDSP.o"
libtool -static -o "$ARCHIVE_SIM/libswvis.a" "$ARCHIVE_SIM/SWVisVDSP.o"

echo "==> Create XCFramework"
xcrun xcodebuild -create-xcframework \
  -library "$ARCHIVE_IOS/libswvis.a" -headers "$HEADERS_DIR" \
  -library "$ARCHIVE_SIM/libswvis.a" -headers "$HEADERS_DIR" \
  -output "$XC_OUT"

echo "OK => $XC_OUT"
