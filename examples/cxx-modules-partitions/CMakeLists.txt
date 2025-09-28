cmake_minimum_required(VERSION 3.28)

project(
  module_partitions_example
  VERSION 1.0.0
  DESCRIPTION "C++20 modules with partitions example using target_install_package")

# C++20 is required for modules
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Check for C++20 modules support using centralized function
include(../check_cxx_modules_support.cmake)
check_cxx_modules_support(modules_supported)
if(NOT modules_supported)
  return()
endif()

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Create math library with C++20 modules and partitions
add_library(math_partitions STATIC)

# Build with C++20 modules and partitions
target_compile_definitions(math_partitions PUBLIC MODULES_AVAILABLE=1)
target_compile_features(math_partitions PUBLIC cxx_std_20)

# Add module partition files using FILE_SET
target_sources(
  math_partitions
  PUBLIC FILE_SET
         CXX_MODULES
         TYPE
         CXX_MODULES
         BASE_DIRS
         "${CMAKE_CURRENT_SOURCE_DIR}/modules"
         FILES
         "modules/math.cppm"
         "modules/math-algebra.cppm"
         "modules/math-geometry.cppm"
         "modules/math-calculus.cppm"
         "modules/math-internal.cppm")

# Add module implementation unit (not part of the public interface)
target_sources(
  math_partitions
  PRIVATE
  "modules/math-impl.cpp")

# Set module-specific properties
set_target_properties(math_partitions PROPERTIES CXX_SCAN_FOR_MODULES ON)

if(APPLE AND CMAKE_OSX_SYSROOT)
  # Forward the macOS SDK so consumers rebuilding module BMIs find system headers
  target_compile_options(math_partitions PUBLIC "-isysroot${CMAKE_OSX_SYSROOT}")
endif()

# Install the library with module support
target_install_package(
  math_partitions
  NAMESPACE
  MathPartitions::
  VERSION
  ${PROJECT_VERSION}
  # Install modules to appropriate destination when available
  MODULE_DESTINATION
  "${CMAKE_INSTALL_INCLUDEDIR}/math_partitions/modules"
  # Also install headers for fallback compatibility
  INCLUDE_DESTINATION
  "${CMAKE_INSTALL_INCLUDEDIR}")
