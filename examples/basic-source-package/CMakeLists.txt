cmake_minimum_required(VERSION 3.25)

project(basic_source_package_example VERSION 1.0.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/load_target_install_package.cmake)

# Create an interface library that ships implementation sources to consumers
add_library(source_ops INTERFACE)

target_sources(
  source_ops
  INTERFACE FILE_SET
            HEADERS
            BASE_DIRS
            "${CMAKE_CURRENT_SOURCE_DIR}/include"
            FILES
            "include/source_ops/arithmetic.hpp")

target_compile_features(source_ops INTERFACE cxx_std_17)

target_install_package(
  source_ops
  NAMESPACE SourceOps::
  VERSION ${PROJECT_VERSION}
  SOURCE_FILES
  src/arithmetic.cpp)
