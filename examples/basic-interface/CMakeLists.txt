cmake_minimum_required(VERSION 3.25)

project(basic_interface_example VERSION 1.5.0)

# Include target_install_package utilities
include(FetchContent)
FetchContent_Declare(
  target_install_package
  GIT_REPOSITORY https://github.com/jkammerland/target_install_package.cmake.git
  GIT_TAG v4.0.1)
FetchContent_MakeAvailable(target_install_package)

# Create an interface (header-only) library
add_library(algorithms INTERFACE)

# Collect all headers
file(GLOB_RECURSE ALGORITHM_HEADERS "include/algorithms/*.hpp")

# Declare interface headers using FILE_SET
target_sources(algorithms INTERFACE FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES ${ALGORITHM_HEADERS})

# Set C++ standard
target_compile_features(algorithms INTERFACE cxx_std_17)

# Install the interface library as a package
target_install_package(algorithms NAMESPACE Algorithms:: VERSION ${PROJECT_VERSION})
