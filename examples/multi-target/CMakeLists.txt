cmake_minimum_required(VERSION 3.25)

project(multi_target_example VERSION 1.0.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Core utility library
add_library(core_utils STATIC)
target_sources(core_utils PRIVATE src/logging.cpp src/config.cpp)
target_sources(
  core_utils
  PUBLIC FILE_SET
         HEADERS
         BASE_DIRS
         "${CMAKE_CURRENT_SOURCE_DIR}/include"
         FILES
         "include/core/logging.h"
         "include/core/config.h")
target_compile_features(core_utils PUBLIC cxx_std_17)

# Math operations library
add_library(math_ops STATIC)
target_sources(math_ops PRIVATE src/operations.cpp)
target_sources(math_ops PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/math/operations.h")
target_compile_features(math_ops PUBLIC cxx_std_17)

# Main engine library that uses both utilities
add_library(game_engine STATIC)
target_sources(game_engine PRIVATE src/engine.cpp)
target_sources(
  game_engine
  PUBLIC FILE_SET
         HEADERS
         BASE_DIRS
         "${CMAKE_CURRENT_SOURCE_DIR}/include"
         FILES
         "include/engine/engine.h"
         "include/engine/api.h")

# Link dependencies
target_link_libraries(game_engine PUBLIC core_utils math_ops)
target_compile_features(game_engine PUBLIC cxx_std_17)

# Install main library with all dependencies in one package
target_install_package(
  game_engine
  NAMESPACE
  GameEngine::
  VERSION
  ${PROJECT_VERSION}
  ADDITIONAL_TARGETS
  core_utils
  math_ops)
