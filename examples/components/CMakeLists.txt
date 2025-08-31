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

# Install with new component prefix pattern (v6.0) - shared export demonstrates logical grouping
# All targets share EXPORT_NAME="MediaLib" to create unified package
target_install_package(
  media_core
  EXPORT_NAME MediaLib
  NAMESPACE Media::
  COMPONENT Core)      # Creates: Core_Runtime, Core_Development

target_install_package(
  media_dev_tools 
  EXPORT_NAME MediaLib
  NAMESPACE Media:: 
  COMPONENT Core)      # Creates: Core_Runtime, Core_Development (same logical group as media_core)

target_install_package(
  asset_converter
  EXPORT_NAME MediaLib
  NAMESPACE Media::
  COMPONENT Tools)     # Creates: Tools_Runtime, Tools_Development

# Use enhanced export_cpack with auto-detection of logical groups
# Components will auto-detected as: Core_Runtime, Core_Development, Tools_Runtime, Tools_Development
# Logical groups will be auto-created: Core (contains Core_*), Tools (contains Tools_*)
# Component dependencies will be auto-set: *_Development depends on *_Runtime
export_cpack(
  PACKAGE_NAME "MediaLibrary"
  PACKAGE_VENDOR "Example Corp" 
  PACKAGE_CONTACT "support@example.com"
  GENERATORS "TGZ"
  # COMPONENT_GROUPS automatically enabled due to prefix detection
  # Components are auto-detected from target_install_package calls
  DEFAULT_COMPONENTS "Core_Runtime;Tools_Runtime"
)
