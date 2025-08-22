cmake_minimum_required(VERSION 3.28)

project(cxx_modules_example VERSION 1.0.0)

# Check for C++20 modules support using helper
include(../CheckCompilerSupport.cmake)
check_cxx_modules_support()

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
