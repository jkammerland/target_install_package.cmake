cmake_minimum_required(VERSION 3.25)

project(components_example VERSION 1.0.0)

# Include target_install_package utilities
include(FetchContent)
FetchContent_Declare(
  target_install_package
  GIT_REPOSITORY https://github.com/jkammerland/target_install_package.cmake.git
  GIT_TAG v4.0.2)
FetchContent_MakeAvailable(target_install_package)

# Core runtime library (shared)
add_library(media_core SHARED)
target_sources(media_core PRIVATE src/media_core.cpp)
target_sources(media_core PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/media/core.h")
set_target_properties(
  media_core
  PROPERTIES POSITION_INDEPENDENT_CODE ON
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})
if(WIN32)
  set_target_properties(media_core PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()
target_compile_features(media_core PUBLIC cxx_std_17)

# Developer utilities (static)
add_library(media_dev_tools STATIC)
target_sources(media_dev_tools PRIVATE src/dev_tools.cpp)
target_sources(media_dev_tools PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/media/dev_tools.h")
target_compile_features(media_dev_tools PUBLIC cxx_std_17)

# Asset converter tool (executable)
add_executable(asset_converter)
target_sources(asset_converter PRIVATE src/asset_converter.cpp)

# Install with custom components
target_install_package(
  media_core
  NAMESPACE
  Media::
  RUNTIME_COMPONENT
  "runtime"
  DEVELOPMENT_COMPONENT
  "devel"
  SUPPORTED_COMPONENTS
  "core"
  "runtime"
  "devel")

target_install_package(
  media_dev_tools
  NAMESPACE
  Media::
  DEVELOPMENT_COMPONENT
  "devel" # Static lib goes to devel
  EXPORT_NAME
  "media_core-targets" # Share the same export
)

target_install_package(
  asset_converter
  NAMESPACE
  Media::
  COMPONENT
  "tools" # Tools get their own component
  RUNTIME_COMPONENT
  "tools")
