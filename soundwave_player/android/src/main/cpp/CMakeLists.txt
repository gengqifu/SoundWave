cmake_minimum_required(VERSION 3.10)
project(soundwave_fft LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(soundwave_fft SHARED
  fft_jni.cpp
  kissfft/kiss_fft.c
  kissfft/kiss_fftr.c
)

target_include_directories(soundwave_fft PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/kissfft
)

find_library(log-lib log)
target_link_libraries(soundwave_fft PRIVATE ${log-lib})
