cmake_minimum_required(VERSION 3.18)
project(soundwave_fft LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

get_filename_component(PROJECT_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../../../../.." ABSOLUTE)
set(NATIVE_CORE_ROOT "${PROJECT_ROOT}/native/core")

add_library(soundwave_fft SHARED
  ${NATIVE_CORE_ROOT}/src/fft_spectrum.cpp
  ${NATIVE_CORE_ROOT}/third_party/kissfft/kiss_fft.c
  ${NATIVE_CORE_ROOT}/third_party/kissfft/kiss_fftr.c
  fft_bridge.cpp
)

target_include_directories(soundwave_fft PRIVATE
  ${NATIVE_CORE_ROOT}/include
  ${NATIVE_CORE_ROOT}/third_party/kissfft
)

find_library(log-lib log)
target_link_libraries(soundwave_fft ${log-lib})
