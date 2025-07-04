cmake_minimum_required(VERSION 3.25)

project(basic_static_example VERSION 1.0.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Create a static library
add_library(math_lib STATIC)
target_sources(math_lib PRIVATE src/math.cpp)

# Declare public headers using FILE_SET (modern CMake approach)
target_sources(math_lib PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/math/calculator.h")

# Set C++ standard
target_compile_features(math_lib PUBLIC cxx_std_17)

# Install the library as a package
target_install_package(math_lib NAMESPACE Math:: VERSION ${PROJECT_VERSION})
