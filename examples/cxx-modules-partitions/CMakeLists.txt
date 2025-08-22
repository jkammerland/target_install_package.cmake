cmake_minimum_required(VERSION 3.28)

project(
  module_partitions_example
  VERSION 1.0.0
  DESCRIPTION "C++20 modules with partitions example using target_install_package")

# Check for C++20 modules support using helper
include(../CheckCompilerSupport.cmake)
check_cxx_modules_support()

# Check generator support for modules
if(NOT CMAKE_GENERATOR MATCHES "Ninja")
  message(WARNING "C++20 modules require Ninja, Ninja Multi-Config. Current generator: ${CMAKE_GENERATOR}")
  message(WARNING "Supported generators: Ninja, Ninja Multi-Config")
  if(WIN32)
    message(WARNING "Unlike the other the other module example, you need Ninja for this one back when I tested it.")
  endif()
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

# Set module-specific properties
set_target_properties(math_partitions PROPERTIES CXX_SCAN_FOR_MODULES ON)

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
