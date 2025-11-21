cmake_minimum_required(VERSION 3.16)
project(soundwave_core LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(SW_BUILD_TESTS "Build tests" ON)

add_library(soundwave_core STATIC
  src/audio_engine_stub.cpp
)
target_include_directories(soundwave_core PUBLIC include)

if(SW_BUILD_TESTS)
  enable_testing()
  find_package(GTest REQUIRED HINTS /usr/local/lib/cmake/GTest)

  add_executable(audio_core_tests
    tests/audio_engine_test.cpp
    src/audio_engine_stub.cpp
  )
  target_include_directories(audio_core_tests PUBLIC include)
  target_link_libraries(audio_core_tests PRIVATE GTest::gtest_main)
  add_test(NAME audio_core_tests COMMAND audio_core_tests)
endif()
