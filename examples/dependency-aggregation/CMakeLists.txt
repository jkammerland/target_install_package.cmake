cmake_minimum_required(VERSION 3.25)
project(dependency_aggregation_example VERSION 2.1.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Core library - dummy implementation with fmt dependency
add_library(core_lib SHARED)
target_sources(core_lib PRIVATE src/dummy.cpp)
target_sources(core_lib PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/mylib/dummy.h")
target_compile_features(core_lib PUBLIC cxx_std_17)
# target_link_libraries(core_lib PRIVATE fmt::fmt)
set_target_properties(core_lib PROPERTIES VERSION ${PROJECT_VERSION} SOVERSION ${PROJECT_VERSION_MAJOR})
if(WIN32)
  set_target_properties(core_lib PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

# Logging library - dummy implementation with spdlog dependency
add_library(logging_lib STATIC)
target_sources(logging_lib PRIVATE src/dummy.cpp)
target_sources(logging_lib PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/mylib/dummy.h")
target_compile_features(logging_lib PUBLIC cxx_std_17)
# target_link_libraries(logging_lib PRIVATE spdlog::spdlog)

# Utilities library - dummy implementation with cxxopts dependency
add_library(utils_lib STATIC)
target_sources(utils_lib PRIVATE src/dummy.cpp)
target_sources(utils_lib PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/mylib/dummy.h")
target_compile_features(utils_lib PUBLIC cxx_std_17)
# target_link_libraries(utils_lib PRIVATE cxxopts::cxxopts)

target_install_package(
  core_lib
  EXPORT_NAME
  "mylib"
  NAMESPACE
  MyLib::
  PUBLIC_DEPENDENCIES
  "fmt 11.1.4 REQUIRED")

target_install_package(
  logging_lib
  EXPORT_NAME
  "mylib"
  NAMESPACE
  MyLib::
  PUBLIC_DEPENDENCIES
  "spdlog 1.15.3 REQUIRED")

target_install_package(
  utils_lib
  EXPORT_NAME
  "mylib"
  NAMESPACE
  MyLib::
  PUBLIC_DEPENDENCIES
  "cxxopts 3.1.1 REQUIRED")

message(STATUS "✅ Dependency aggregation example configured successfully")
message(STATUS "   - 3 targets will be packaged into 'mylib' export")
message(STATUS "   - Generated config will contain fmt, spdlog, and cxxopts dependencies")
