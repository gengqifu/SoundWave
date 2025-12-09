cmake_minimum_required(VERSION 3.18.1)
project(visualizationcore)

# 接入 native/core 的可视化闭环（合成信号 + PCM/FFT 回调）。
set(CORE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../core)

add_library(visualizationcore SHARED
    visualization_jni.cpp
    ${CORE_DIR}/src/visualization_core_stub.cpp
    ${CORE_DIR}/src/pcm_throttler.cpp
    ${CORE_DIR}/src/fft_spectrum.cpp
    ${CORE_DIR}/third_party/kissfft/kiss_fft.c
    ${CORE_DIR}/third_party/kissfft/kiss_fftr.c
)

target_include_directories(visualizationcore PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CORE_DIR}/include
    ${CORE_DIR}/third_party/kissfft
)

find_library(log-lib log)

target_link_libraries(visualizationcore ${log-lib})
