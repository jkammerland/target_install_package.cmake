cmake_minimum_required(VERSION 3.25)

project(multi_config_example VERSION 1.0.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Create a shared library
add_library(math_utils SHARED)
target_sources(math_utils PRIVATE src/math_utils.cpp)

# Declare public headers using FILE_SET
target_sources(math_utils PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/utils/math_utils.h")

# Set properties for shared library
set_target_properties(
  math_utils
  PROPERTIES POSITION_INDEPENDENT_CODE ON
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})

# Windows-specific: ensure import library is generated
if(WIN32)
  set_target_properties(math_utils PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

# Set C++ standard
target_compile_features(math_utils PUBLIC cxx_std_17)

# Install the library as a package with multi-config support
target_install_package(math_utils 
  NAMESPACE Utils:: 
  VERSION ${PROJECT_VERSION}
  DEBUG_POSTFIX "d")