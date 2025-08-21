cmake_minimum_required(VERSION 3.28)

project(module_partitions_example VERSION 1.0.0 DESCRIPTION "C++20 modules with partitions example using target_install_package")

# C++20 is required for modules
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Check for C++20 modules support - exit early if not supported
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "14.0")
    message(WARNING "GCC 14.0 or later is required for C++20 modules support. Current version: ${CMAKE_CXX_COMPILER_VERSION}")
    return()
  endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "19.0")
    message(WARNING "Clang 19.0 or later is required for C++20 modules support. Current version: ${CMAKE_CXX_COMPILER_VERSION}")
    return()
  endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "19.29")
    message(WARNING "MSVC 19.29 (Visual Studio 2019 16.10) or later is required for C++20 modules support. Current version: ${CMAKE_CXX_COMPILER_VERSION}")
    return()
  endif()
else()
  message(WARNING "C++20 modules support may not be available with ${CMAKE_CXX_COMPILER_ID}. Skipping modules example.")
  return()
endif()

message(STATUS "C++20 modules support detected - building with modules")

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Create math library with C++20 modules and partitions
add_library(math_partitions STATIC)

# Build with C++20 modules and partitions
target_compile_definitions(math_partitions PUBLIC MODULES_AVAILABLE=1)
target_compile_features(math_partitions PUBLIC cxx_std_20)

# Add module partition files using FILE_SET
target_sources(math_partitions
  PUBLIC FILE_SET CXX_MODULES
  TYPE CXX_MODULES
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/modules"
  FILES
    "modules/math.cppm"
    "modules/math-algebra.cppm"
    "modules/math-geometry.cppm"
    "modules/math-calculus.cppm"
    "modules/math-internal.cppm"
)

# Set module-specific properties
set_target_properties(math_partitions PROPERTIES 
  CXX_SCAN_FOR_MODULES ON
)


# Install the library with module support
target_install_package(
  math_partitions
  NAMESPACE MathPartitions::
  VERSION ${PROJECT_VERSION}
  # Install modules to appropriate destination when available
  MODULE_DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/math_partitions/modules"
  # Also install headers for fallback compatibility
  INCLUDE_DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}"
)

