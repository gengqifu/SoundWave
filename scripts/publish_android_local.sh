#!/usr/bin/env bash
set -euo pipefail

# 发布 Android AAR 到本地 Maven 目录（无需外网/中央仓库）。
# 可通过环境变量覆盖：
#   VERSION    版本号（默认 0.0.2-local）
#   REPO_DIR   本地仓库输出目录（默认 $ROOT/build/maven-repo）
#   GRADLE_BIN Gradle 可执行路径（默认 ~/.gradle/wrapper/dists/gradle-8.1.1-bin/gradle-8.1.1/bin/gradle）

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$ROOT/soundwave_player/android"
VERSION="${VERSION:-0.0.2-local}"
REPO_DIR="${REPO_DIR:-$ROOT/build/maven-repo}"
GRADLE_BIN="${GRADLE_BIN:-$HOME/.gradle/wrapper/dists/gradle-8.1.1-bin/gradle-8.1.1/bin/gradle}"

echo "==> Build AARs (release)..."
GRADLE_OPTS="${GRADLE_OPTS:--Dorg.gradle.native=false}" \
  "$GRADLE_BIN" -p "$ANDROID_DIR" assembleRelease

ARTIFACTS=(
  "core:$ANDROID_DIR/core/build/outputs/aar/core-release.aar"
  "adapter:$ANDROID_DIR/adapter/build/outputs/aar/adapter-release.aar"
  "soundwave_player:$ANDROID_DIR/build/outputs/aar/soundwave_player-release.aar"
)

for entry in "${ARTIFACTS[@]}"; do
  name="${entry%%:*}"
  src="${entry#*:}"
  if [[ ! -f "$src" ]]; then
    echo "!! missing artifact: $src" >&2
    exit 1
  fi
  dest="$REPO_DIR/com/soundwave/soundwave_player/$name/$VERSION"
  mkdir -p "$dest"
  cp "$src" "$dest/${name}-${VERSION}.aar"
  cat > "$dest/${name}-${VERSION}.pom" <<EOF
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.soundwave.soundwave_player</groupId>
  <artifactId>${name}</artifactId>
  <version>${VERSION}</version>
  <packaging>aar</packaging>
  <name>SoundWave ${name}</name>
  <description>Local build of SoundWave Android ${name}</description>
</project>
EOF
  echo "  -> installed ${name}-${VERSION} to $dest"
done

echo "Done. Local repo at: $REPO_DIR"
