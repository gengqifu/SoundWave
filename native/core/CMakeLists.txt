cmake_minimum_required(VERSION 3.16)
project(soundwave_core LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(SW_BUILD_TESTS "Build tests" ON)
option(SW_ENABLE_FFMPEG "Link FFmpeg libraries when available" OFF)

set(FFMPEG_ROOT_DESKTOP "" CACHE PATH "FFmpeg install prefix for desktop builds")
set(FFMPEG_ROOT_IOS "" CACHE PATH "FFmpeg install prefix for iOS builds")
set(FFMPEG_ROOT_ANDROID "" CACHE PATH "FFmpeg install prefix for Android builds")

add_library(soundwave_core STATIC
  src/audio_engine_stub.cpp
  src/decoder_stub.cpp
)
target_include_directories(soundwave_core PUBLIC include)

if(SW_ENABLE_FFMPEG)
  target_sources(soundwave_core PRIVATE src/decoder_ffmpeg.cpp)
endif()

if(SW_ENABLE_FFMPEG)
  if(ANDROID)
    set(_ffroot "${FFMPEG_ROOT_ANDROID}")
  elseif(IOS)
    set(_ffroot "${FFMPEG_ROOT_IOS}")
  else()
    set(_ffroot "${FFMPEG_ROOT_DESKTOP}")
  endif()

  if(NOT _ffroot)
    message(FATAL_ERROR "SW_ENABLE_FFMPEG=ON but FFMPEG_ROOT_* not set for this platform")
  endif()

  set(FFMPEG_INCLUDE_DIR "${_ffroot}/include")
  set(FFMPEG_LIB_DIR "${_ffroot}/lib")

  find_library(FFMPEG_AVFORMAT avformat PATHS "${FFMPEG_LIB_DIR}" NO_DEFAULT_PATH)
  find_library(FFMPEG_AVCODEC avcodec PATHS "${FFMPEG_LIB_DIR}" NO_DEFAULT_PATH)
  find_library(FFMPEG_AVUTIL avutil PATHS "${FFMPEG_LIB_DIR}" NO_DEFAULT_PATH)
  find_library(FFMPEG_SWRESAMPLE swresample PATHS "${FFMPEG_LIB_DIR}" NO_DEFAULT_PATH)
  find_library(FFMPEG_SWSCALE swscale PATHS "${FFMPEG_LIB_DIR}" NO_DEFAULT_PATH)

  if(NOT FFMPEG_AVFORMAT OR NOT FFMPEG_AVCODEC OR NOT FFMPEG_AVUTIL)
    message(FATAL_ERROR "FFmpeg libraries not found under ${_ffroot}/lib")
  endif()

  target_include_directories(soundwave_core PRIVATE "${FFMPEG_INCLUDE_DIR}")
  target_link_libraries(soundwave_core PRIVATE
    ${FFMPEG_AVFORMAT}
    ${FFMPEG_AVCODEC}
    ${FFMPEG_AVUTIL}
    ${FFMPEG_SWRESAMPLE}
    ${FFMPEG_SWSCALE}
  )
endif()

if(SW_BUILD_TESTS AND NOT ANDROID AND NOT IOS)
  enable_testing()
  find_package(GTest QUIET HINTS /usr/local/lib/cmake/GTest)
  if(GTest_FOUND)
    add_executable(audio_core_tests
      tests/audio_engine_test.cpp
    )
    target_link_libraries(audio_core_tests PRIVATE soundwave_core GTest::gtest_main)
    add_test(NAME audio_core_tests COMMAND audio_core_tests)
  else()
    message(WARNING "GTest not found; tests will be skipped")
  endif()

endif()
