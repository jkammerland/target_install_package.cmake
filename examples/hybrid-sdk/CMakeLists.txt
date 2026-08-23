cmake_minimum_required(VERSION 4.4)

project(hybrid_sdk VERSION 1.0.0 LANGUAGES CXX)

set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
if(DEFINED TARGET_INSTALL_PACKAGE_ROOT)
  include("${TARGET_INSTALL_PACKAGE_ROOT}/cmake/load_target_install_package.cmake")
else()
  include("${CMAKE_CURRENT_LIST_DIR}/../../cmake/load_target_install_package.cmake")
endif()

set(HYBRID_SDK_SOURCE_DESTINATION
    ""
    CACHE STRING "Optional destination for installed extension sources")
set(_hybrid_source_destination_args "")
if(NOT "${HYBRID_SDK_SOURCE_DESTINATION}" STREQUAL "")
  list(APPEND _hybrid_source_destination_args SOURCE_DESTINATION "${HYBRID_SDK_SOURCE_DESTINATION}")
endif()

add_library(hybrid_runtime SHARED)
target_sources(hybrid_runtime PRIVATE src/runtime.cpp)
target_sources(hybrid_runtime PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/hybrid/runtime.hpp")
target_compile_features(hybrid_runtime PUBLIC cxx_std_17)
set_target_properties(
  hybrid_runtime
  PROPERTIES VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})
if(WIN32)
  set_target_properties(hybrid_runtime PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

add_library(hybrid_extension INTERFACE)
target_sources(hybrid_extension INTERFACE FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/hybrid/extension.hpp")
target_sources(hybrid_extension INTERFACE FILE_SET implementation TYPE SOURCES BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/src" FILES "src/extension.cpp")
target_link_libraries(hybrid_extension INTERFACE hybrid_runtime)
target_compile_features(hybrid_extension INTERFACE cxx_std_17)

add_library(hybrid_sdk INTERFACE)
target_sources(hybrid_sdk INTERFACE FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/hybrid/sdk.hpp")
target_link_libraries(hybrid_sdk INTERFACE hybrid_runtime hybrid_extension)
target_compile_features(hybrid_sdk INTERFACE cxx_std_17)

target_install_package(
  hybrid_runtime
  EXPORT_NAME
  hybrid_sdk
  NAMESPACE
  HybridSdk::
  ALIAS_NAME
  runtime
  VERSION
  ${PROJECT_VERSION}
  ${_hybrid_source_destination_args})

target_install_package(
  hybrid_extension
  EXPORT_NAME
  hybrid_sdk
  NAMESPACE
  HybridSdk::
  ALIAS_NAME
  extension
  VERSION
  ${PROJECT_VERSION}
  ${_hybrid_source_destination_args})

target_install_package(
  hybrid_sdk
  EXPORT_NAME
  hybrid_sdk
  NAMESPACE
  HybridSdk::
  ALIAS_NAME
  sdk
  VERSION
  ${PROJECT_VERSION}
  ${_hybrid_source_destination_args})
