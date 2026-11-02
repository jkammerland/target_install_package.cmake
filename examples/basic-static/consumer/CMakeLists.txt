cmake_minimum_required(VERSION 3.25)
project(math_consumer LANGUAGES CXX)

# Both dependency sources provide exactly the same public target.
option(MATH_FROM_SOURCE "Build the math library from source" OFF)
if(MATH_FROM_SOURCE)
  add_subdirectory(.. math-build)
  if(MATH_INSTALL)
    message(FATAL_ERROR "Embedded math installation should default to OFF")
  endif()
else()
  find_package(math_lib CONFIG REQUIRED)
endif()

add_executable(math_consumer main.cpp)
target_link_libraries(math_consumer PRIVATE Math::math_lib)

enable_testing()
add_test(NAME calculator COMMAND math_consumer)
