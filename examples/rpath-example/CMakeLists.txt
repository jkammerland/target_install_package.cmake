cmake_minimum_required(VERSION 3.25)

project(rpath_example VERSION 1.0.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Create a shared library
add_library(mylib SHARED)
target_sources(mylib PRIVATE src/mylib.cpp)

# Declare public headers using FILE_SET
target_sources(mylib PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/mylib/mylib.h")

# Set properties for shared library
set_target_properties(
  mylib
  PROPERTIES POSITION_INDEPENDENT_CODE ON
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})

# Windows-specific: ensure import library is generated
if(WIN32)
  set_target_properties(mylib PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

# Set C++ standard
target_compile_features(mylib PUBLIC cxx_std_17)

# Create executable that uses the library
add_executable(rpath_demo)
target_sources(rpath_demo PRIVATE src/main.cpp)
target_link_libraries(rpath_demo PRIVATE mylib)
target_compile_features(rpath_demo PRIVATE cxx_std_17)

# Install the library as a package
target_install_package(mylib NAMESPACE RpathExample:: VERSION ${PROJECT_VERSION})

# Install the executable as a separate package component
target_install_package(
  rpath_demo
  NAMESPACE RpathExample::
  COMPONENT "tools"
  RUNTIME_COMPONENT "tools")