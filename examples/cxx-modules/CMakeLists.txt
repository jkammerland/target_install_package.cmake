cmake_minimum_required(VERSION 3.28)

project(cxx_modules_example VERSION 1.0.0)

# C++20 is required for modules
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Check for C++20 modules support
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "14.0")
    message(WARNING "GCC 14.0 or later is recommended for C++20 modules support. Current version: ${CMAKE_CXX_COMPILER_VERSION}")
    return()
  endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "19.0")
    message(WARNING "Clang 19.0 or later is recommended for C++20 modules support. Current version: ${CMAKE_CXX_COMPILER_VERSION}")
    return()
  endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "19.29")
    message(WARNING "MSVC 19.29 (Visual Studio 2019 16.10) or later is recommended for C++20 modules support. Current version: ${CMAKE_CXX_COMPILER_VERSION}")
    return()
  endif()
else()
  message(WARNING "C++20 modules support may not be available with ${CMAKE_CXX_COMPILER_ID}. Skipping modules example.")
  return()
endif()

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Create a library with C++20 modules
add_library(math_modules STATIC)

# Add implementation sources
target_sources(math_modules PRIVATE src/math_impl.cpp)

# Add C++20 modules using FILE_SET
target_sources(
  math_modules
  PUBLIC FILE_SET
         CXX_MODULES
         TYPE
         CXX_MODULES
         BASE_DIRS
         "${CMAKE_CURRENT_SOURCE_DIR}/modules"
         FILES
         "modules/math.cppm"
         "modules/geometry.cppm")

# Set module-specific properties
set_target_properties(math_modules PROPERTIES CXX_SCAN_FOR_MODULES ON)

# Install the library with module support
target_install_package(
  math_modules
  NAMESPACE
  MathModules::
  VERSION
  ${PROJECT_VERSION}
  MODULE_DESTINATION
  "${CMAKE_INSTALL_INCLUDEDIR}/math_modules/modules")
