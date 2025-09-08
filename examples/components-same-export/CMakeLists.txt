cmake_minimum_required(VERSION 3.25)

project(components_example VERSION 1.0.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Core runtime library (shared)
add_library(media_core2 SHARED)
target_sources(media_core2 PRIVATE src/media_core.cpp)
target_sources(media_core2 PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/media/core.h")
set_target_properties(
  media_core2
  PROPERTIES POSITION_INDEPENDENT_CODE ON
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})
if(WIN32)
  set_target_properties(media_core2 PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()
target_compile_features(media_core2 PUBLIC cxx_std_17)

# Developer utilities (static)
add_library(media_dev_tools2 STATIC)
target_sources(media_dev_tools2 PRIVATE src/dev_tools.cpp)
target_sources(media_dev_tools2 PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/media/dev_tools.h")
target_compile_features(media_dev_tools2 PUBLIC cxx_std_17)

# db
add_library(storage SHARED)
target_sources(storage PRIVATE src/storage.cpp)
target_sources(storage PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/storage/storage.h")
target_compile_features(storage PUBLIC cxx_std_20)

set_target_properties(
  storage
  PROPERTIES POSITION_INDEPENDENT_CODE ON
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR})
if(WIN32)
  set_target_properties(storage PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

# Asset converter tool (executable)
add_executable(asset_converter2)
target_sources(asset_converter2 PRIVATE src/asset_converter.cpp)

# Install with meaningful component names
target_install_package(
  media_core2
  EXPORT_NAME
  "engine2"
  NAMESPACE
  Media::
  COMPONENT
  "Core") # Creates Core + Core_Development

target_install_package(
  media_dev_tools2
  EXPORT_NAME
  "engine2"
  NAMESPACE
  Media::
  COMPONENT
  "DevTools") # Creates DevTools + DevTools_Development

target_install_package(
  storage
  EXPORT_NAME
  "engine2"
  NAMESPACE
  Media::
  COMPONENT
  "Storage") # Creates Storage + Storage_Development

target_install_package(
  asset_converter2
  EXPORT_NAME
  "engine2"
  NAMESPACE
  Media::
  COMPONENT
  "Tools") # Creates Tools + Tools_Development
