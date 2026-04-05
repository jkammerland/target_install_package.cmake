cmake_minimum_required(VERSION 3.25)

project(sdk_hybrid_example VERSION 1.0.0 LANGUAGES CXX)

set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/load_target_install_package.cmake)

add_library(sdk_runtime SHARED)
target_sources(sdk_runtime PRIVATE src/runtime.cpp)
target_sources(
  sdk_runtime
  PUBLIC FILE_SET
         HEADERS
         BASE_DIRS
         "${CMAKE_CURRENT_SOURCE_DIR}/include"
         FILES
         "include/hybrid_sdk/runtime.hpp")
target_compile_features(sdk_runtime PUBLIC cxx_std_17)
set_target_properties(
  sdk_runtime
  PROPERTIES POSITION_INDEPENDENT_CODE ON
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})
if(WIN32)
  set_target_properties(sdk_runtime PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

add_library(sdk_open_algorithms INTERFACE)
target_sources(
  sdk_open_algorithms
  INTERFACE FILE_SET
            HEADERS
            BASE_DIRS
            "${CMAKE_CURRENT_SOURCE_DIR}/include"
            FILES
            "include/hybrid_sdk/open_algorithms.hpp")
target_link_libraries(sdk_open_algorithms INTERFACE sdk_runtime)
target_compile_features(sdk_open_algorithms INTERFACE cxx_std_17)

add_library(sdk INTERFACE)
target_sources(
  sdk
  INTERFACE FILE_SET
            HEADERS
            BASE_DIRS
            "${CMAKE_CURRENT_SOURCE_DIR}/include"
            FILES
            "include/hybrid_sdk/sdk.hpp")
target_link_libraries(sdk INTERFACE sdk_runtime sdk_open_algorithms)
target_compile_features(sdk INTERFACE cxx_std_17)

target_install_package(
  sdk_runtime
  EXPORT_NAME
  hybrid_sdk
  NAMESPACE
  HybridSdk::
  VERSION
  ${PROJECT_VERSION})

target_install_package(
  sdk_open_algorithms
  EXPORT_NAME
  hybrid_sdk
  NAMESPACE
  HybridSdk::
  VERSION
  ${PROJECT_VERSION}
  SOURCE_FILES
  src/open_algorithms.cpp)

target_install_package(
  sdk
  EXPORT_NAME
  hybrid_sdk
  NAMESPACE
  HybridSdk::
  VERSION
  ${PROJECT_VERSION})
