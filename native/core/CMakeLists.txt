cmake_minimum_required(VERSION 3.16)
project(soundwave_core LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

option(SW_BUILD_TESTS "Build tests" ON)

add_library(soundwave_core STATIC
  src/audio_engine_stub.cpp
  src/decoder_stub.cpp
  src/ring_buffer.cpp
  src/playback_thread.cpp
  src/pcm_throttler.cpp
  src/fft_spectrum.cpp
  src/visualization_core_stub.cpp
  third_party/kissfft/kiss_fft.c
  third_party/kissfft/kiss_fftr.c
)
target_include_directories(soundwave_core PUBLIC include)
target_include_directories(soundwave_core PUBLIC
  third_party/kissfft
)

if(SW_BUILD_TESTS AND NOT ANDROID AND NOT IOS)
  enable_testing()
  find_package(GTest QUIET HINTS /usr/local/lib/cmake/GTest)
  if(GTest_FOUND)
    add_executable(audio_core_tests
      tests/audio_engine_test.cpp
      tests/ring_buffer_test.cpp
      tests/playback_thread_test.cpp
      tests/pcm_throttle_test.cpp
      tests/fft_spectrum_test.cpp
    )
    target_link_libraries(audio_core_tests PRIVATE soundwave_core GTest::gtest_main)
    add_test(NAME audio_core_tests COMMAND audio_core_tests)
    add_test(NAME ring_buffer_tests COMMAND audio_core_tests --gtest_filter=RingBufferTest.*)
    add_test(NAME playback_thread_tests COMMAND audio_core_tests --gtest_filter=PlaybackThreadTest.*)
    add_test(NAME pcm_throttle_tests COMMAND audio_core_tests --gtest_filter=PcmThrottleTest.*)
    add_test(NAME fft_spectrum_tests COMMAND audio_core_tests --gtest_filter=FftSpectrumTest.*)
  else()
    message(WARNING "GTest not found; tests will be skipped")
  endif()

  add_executable(fft_compare tests/fft_compare_main.cpp)
  target_link_libraries(fft_compare PRIVATE soundwave_core)

endif()
