cmake_minimum_required(VERSION 3.25)

project(
  sdk_example
  VERSION 1.0.0
  LANGUAGES CXX)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/load_target_install_package.cmake)

# Runtime library: this is the ABI-bearing shared object an SDK would ship in its target sysroot.
add_library(sdk_runtime SHARED)
target_sources(sdk_runtime PRIVATE src/runtime.cpp)
target_sources(sdk_runtime PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/sdk/runtime.hpp")
target_compile_features(sdk_runtime PUBLIC cxx_std_17)
set_target_properties(
  sdk_runtime
  PROPERTIES POSITION_INDEPENDENT_CODE ON
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})
if(WIN32)
  set_target_properties(sdk_runtime PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

# Static development library: this lands in the development/static SDK payload and can depend on the shared runtime.
add_library(sdk_algorithms STATIC)
target_sources(sdk_algorithms PRIVATE src/algorithms.cpp)
target_sources(sdk_algorithms PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/sdk/algorithms.hpp")
target_link_libraries(sdk_algorithms PUBLIC sdk_runtime)
target_compile_features(sdk_algorithms PUBLIC cxx_std_17)

# Umbrella target: consumers can link one target while still receiving the prebuilt shared/static libraries and headers from the installed package.
add_library(sdk INTERFACE)
target_sources(sdk INTERFACE FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/sdk/sdk.hpp")
target_link_libraries(sdk INTERFACE sdk_runtime sdk_algorithms)
target_compile_features(sdk INTERFACE cxx_std_17)

target_install_package(
  sdk_runtime
  EXPORT_NAME
  sdk
  NAMESPACE
  Sdk::
  ALIAS_NAME
  runtime
  VERSION
  ${PROJECT_VERSION})

target_install_package(
  sdk_algorithms
  EXPORT_NAME
  sdk
  NAMESPACE
  Sdk::
  ALIAS_NAME
  algorithms
  VERSION
  ${PROJECT_VERSION})

target_install_package(
  sdk
  EXPORT_NAME
  sdk
  NAMESPACE
  Sdk::
  VERSION
  ${PROJECT_VERSION})
