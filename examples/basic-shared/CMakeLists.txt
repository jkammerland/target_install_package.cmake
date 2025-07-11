cmake_minimum_required(VERSION 3.25)

project(basic_shared_example VERSION 2.1.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Create a shared library
add_library(string_utils SHARED)
target_sources(string_utils PRIVATE src/string_utils.cpp)

# Declare public headers using FILE_SET
target_sources(string_utils PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/utils/string_utils.h")

# Set properties for shared library
set_target_properties(
  string_utils
  PROPERTIES POSITION_INDEPENDENT_CODE ON
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})

# Windows-specific: ensure import library is generated
if(WIN32)
  set_target_properties(string_utils PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

# Set C++ standard
target_compile_features(string_utils PUBLIC cxx_std_17)

# Install the library as a package
target_install_package(string_utils NAMESPACE Utils:: VERSION ${PROJECT_VERSION})
