cmake_minimum_required(VERSION 3.25)

project(
  source_package_export_fixture
  VERSION 1.0.0
  LANGUAGES CXX)

if(NOT DEFINED TIP_REPO_ROOT)
  message(FATAL_ERROR "TIP_REPO_ROOT must be provided to source-package-export fixture")
endif()

include("${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake")
include("${TIP_REPO_ROOT}/cmake/project_log.cmake")
include("${TIP_REPO_ROOT}/target_install_package.cmake")
find_package(Threads REQUIRED)

add_library(export_runtime SHARED src/runtime.cpp)
target_sources(
  export_runtime
  PUBLIC FILE_SET
         HEADERS
         BASE_DIRS
         "${CMAKE_CURRENT_SOURCE_DIR}/include"
         FILES
         "include/source_sdk/runtime.hpp")
target_compile_features(export_runtime PUBLIC cxx_std_17)
set_target_properties(
  export_runtime
  PROPERTIES POSITION_INDEPENDENT_CODE ON
             WINDOWS_EXPORT_ALL_SYMBOLS ON
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})
add_library(export_runtime_alias ALIAS export_runtime)

add_library(export_support STATIC src/support.cpp)
target_compile_features(export_support PUBLIC cxx_std_17)

add_library(export_algorithms SHARED)
target_sources(
  export_algorithms
  PRIVATE src/algorithms.cpp
  PUBLIC FILE_SET
         HEADERS
         BASE_DIRS
         "${CMAKE_CURRENT_SOURCE_DIR}/include"
         FILES
         "include/source_sdk/algorithms.hpp")
target_link_libraries(export_algorithms PUBLIC "$<$<BOOL:1>:export_runtime_alias>" PRIVATE export_support "$<$<BOOL:1>:Threads::Threads>")
target_compile_features(export_algorithms PUBLIC cxx_std_17)
target_link_options(
  export_algorithms
  PUBLIC "$<BUILD_INTERFACE:$<$<PLATFORM_ID:Linux>:LINKER:-z,defs>>"
         "$<INSTALL_INTERFACE:$<$<PLATFORM_ID:Linux>:LINKER:-z,origin>>")
set_target_properties(export_algorithms PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON POSITION_INDEPENDENT_CODE ON)

add_library(export_sdk INTERFACE)
target_sources(
  export_sdk
  INTERFACE FILE_SET
            HEADERS
            BASE_DIRS
            "${CMAKE_CURRENT_SOURCE_DIR}/include"
            FILES
            "include/source_sdk/sdk.hpp")
target_link_libraries(export_sdk INTERFACE "$<$<BOOL:1>:export_runtime_alias>" export_algorithms)
target_compile_features(export_sdk INTERFACE cxx_std_17)

target_install_package(
  export_runtime
  EXPORT_NAME
  source_sdk
  NAMESPACE
  SourceSdk::
  VERSION
  ${PROJECT_VERSION})

target_install_package(
  export_support
  EXPORT_NAME
  source_sdk
  NAMESPACE
  SourceSdk::
  VERSION
  ${PROJECT_VERSION})

target_install_package(
  export_algorithms
  EXPORT_NAME
  source_sdk
  NAMESPACE
  SourceSdk::
  VERSION
  ${PROJECT_VERSION}
  PUBLIC_DEPENDENCIES
  "Threads"
  ALIAS_NAME
  export_algorithms_prebuilt)

target_install_package(
  export_algorithms
  EXPORT_NAME
  source_sdk
  NAMESPACE
  SourceSdk::
  VERSION
  ${PROJECT_VERSION}
  PUBLIC_DEPENDENCIES
  "Threads"
  INCLUDE_SOURCES
  EXCLUSIVE)

target_install_package(
  export_sdk
  EXPORT_NAME
  source_sdk
  NAMESPACE
  SourceSdk::
  VERSION
  ${PROJECT_VERSION}
  INCLUDE_SOURCES
  EXCLUSIVE)
