#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:-build}"
CMAKE_FLAGS="${CMAKE_FLAGS:-}"

echo "[perf-smoke] Configure build dir: ${BUILD_DIR}"
cmake -S . -B "${BUILD_DIR}" -DSW_BUILD_TESTS=ON ${CMAKE_FLAGS}

echo "[perf-smoke] Build tests"
cmake --build "${BUILD_DIR}"

echo "[perf-smoke] Run FFT/perf smoke cases"
# ctest target name is fft_spectrum_tests; rely on gtest filter to narrow cases if needed.
ctest --test-dir "${BUILD_DIR}" -V -R "fft_spectrum_tests"
