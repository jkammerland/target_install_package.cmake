cmake_minimum_required(VERSION 3.25)

project(configure_files_example VERSION 2.3.1)

# Include target_install_package utilities
include(FetchContent)
FetchContent_Declare(
  target_install_package
  GIT_REPOSITORY https://github.com/jkammerland/target_install_package.cmake.git
  GIT_TAG v3.0.3
)
FetchContent_MakeAvailable(target_install_package)

# Set some project variables for configuration
set(LIBRARY_DESCRIPTION "Example library demonstrating configure file usage")
set(LIBRARY_AUTHOR "CMake Examples Team")
set(ENABLE_LOGGING ON)
set(MAX_BUFFER_SIZE 1024)

# Create a library
add_library(config_lib STATIC)
target_sources(config_lib PRIVATE src/config_lib.cpp)

# Declare regular headers using FILE_SET
target_sources(config_lib PUBLIC 
  FILE_SET HEADERS 
  BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" 
  FILES "include/config/library.h"
)

# Configure template files and add them to the target
target_configure_sources(config_lib
  PUBLIC
  FILE_SET HEADERS
  BASE_DIRS ${CMAKE_CURRENT_BINARY_DIR}/include/config
  FILES 
    ${CMAKE_CURRENT_SOURCE_DIR}/include/config/version.h.in
    ${CMAKE_CURRENT_SOURCE_DIR}/include/config/build_info.h.in
)

target_configure_sources(config_lib
  PRIVATE
  FILE_SET private_config
  BASE_DIRS ${CMAKE_CURRENT_BINARY_DIR}/include/config
  FILES 
    ${CMAKE_CURRENT_SOURCE_DIR}/include/config/internal_config.h.in
)

# Set C++ standard
target_compile_features(config_lib PUBLIC cxx_std_17)

# Install the library as a package
target_install_package(config_lib
  NAMESPACE Config::
  VERSION ${PROJECT_VERSION}
)