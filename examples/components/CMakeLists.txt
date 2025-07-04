cmake_minimum_required(VERSION 3.25)

project(components_example VERSION 1.0.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

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
  "devel")

target_install_package(media_dev_tools NAMESPACE Media:: DEVELOPMENT_COMPONENT "devel")

target_install_package(
  asset_converter
  NAMESPACE
  Media::
  COMPONENT
  "tools" # Tools get their own component
  RUNTIME_COMPONENT
  "tools")

# Basic CPack configuration to test component packaging
set(CPACK_PACKAGE_NAME "MediaLibrary")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_GENERATOR "TGZ")

# Define components
set(CPACK_COMPONENT_RUNTIME_DISPLAY_NAME "Runtime Libraries")
set(CPACK_COMPONENT_RUNTIME_DESCRIPTION "Runtime libraries required to run applications")

set(CPACK_COMPONENT_DEVEL_DISPLAY_NAME "Development Files")
set(CPACK_COMPONENT_DEVEL_DESCRIPTION "Headers and development files")

set(CPACK_COMPONENT_TOOLS_DISPLAY_NAME "Tools")
set(CPACK_COMPONENT_TOOLS_DESCRIPTION "Asset conversion tools")

# Custom components (these should be auto-created by our dual install)
set(CPACK_COMPONENT_TOOLS-RUNTIME_DISPLAY_NAME "Tools Runtime")
set(CPACK_COMPONENT_TOOLS-RUNTIME_DESCRIPTION "Runtime files for tools component")

set(CPACK_COMPONENT_TOOLS-DEVELOPMENT_DISPLAY_NAME "Tools Development")
set(CPACK_COMPONENT_TOOLS-DEVELOPMENT_DESCRIPTION "Development files for tools component")

include(CPack)
