cmake_minimum_required(VERSION 3.25)
project(dependency_aggregation_example VERSION 2.1.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Use FetchContent to provide dependencies needed by the generated config
include(FetchContent)

# Use OVERRIDE_FIND_PACKAGE so downstream find_dependency() calls work seamlessly
FetchContent_Declare(
  fmt
  GIT_REPOSITORY https://github.com/fmtlib/fmt.git
  GIT_TAG 11.1.4
  OVERRIDE_FIND_PACKAGE
  EXCLUDE_FROM_ALL)  # Don't install these dependencies by default

FetchContent_Declare(
  spdlog
  GIT_REPOSITORY https://github.com/gabime/spdlog.git
  GIT_TAG v1.14.1
  OVERRIDE_FIND_PACKAGE
  EXCLUDE_FROM_ALL)

FetchContent_Declare(
  cxxopts
  GIT_REPOSITORY https://github.com/jarro2783/cxxopts.git
  GIT_TAG v3.1.1
  OVERRIDE_FIND_PACKAGE
  EXCLUDE_FROM_ALL)

# Option to control whether to install the dependencies
option(DEPENDENCY_AGGREGATION_INSTALL_DEPS "Install FetchContent dependencies with this package" OFF)

# Set policy to avoid FetchContent_Populate deprecation warnings
if(POLICY CMP0169)
  cmake_policy(SET CMP0169 OLD)
endif()

# Set spdlog options for better compatibility
set(SPDLOG_BUILD_EXAMPLE OFF CACHE BOOL "" FORCE)
set(SPDLOG_BUILD_BENCH OFF CACHE BOOL "" FORCE)
set(SPDLOG_BUILD_TESTS OFF CACHE BOOL "" FORCE)

if(DEPENDENCY_AGGREGATION_INSTALL_DEPS)
  # Install dependencies along with this package
  FetchContent_MakeAvailable(fmt spdlog cxxopts)
else()
  # Make dependencies available for building but exclude from installation
  FetchContent_MakeAvailable(fmt spdlog cxxopts)
  
  # Mark FetchContent targets to exclude from installation
  # This prevents them from being installed with cmake --install
  set_target_properties(fmt PROPERTIES EXCLUDE_FROM_ALL TRUE)
  if(TARGET spdlog)
    set_target_properties(spdlog PROPERTIES EXCLUDE_FROM_ALL TRUE)
  endif()
  if(TARGET cxxopts)
    set_target_properties(cxxopts PROPERTIES EXCLUDE_FROM_ALL TRUE)
  endif()
endif()

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
  "fmt 11.1.4 REQUIRED"
  RUNTIME_COMPONENT
  "runtime"
  DEVELOPMENT_COMPONENT
  "dev")

target_install_package(
  logging_lib
  EXPORT_NAME
  "mylib"
  NAMESPACE
  MyLib::
  PUBLIC_DEPENDENCIES
  "spdlog 1.14.1 REQUIRED"
  DEVELOPMENT_COMPONENT
  "dev")

target_install_package(
  utils_lib
  EXPORT_NAME
  "mylib"
  NAMESPACE
  MyLib::
  PUBLIC_DEPENDENCIES
  "cxxopts 3.1.1 REQUIRED"
  DEVELOPMENT_COMPONENT
  "dev")

message(STATUS "✅ Dependency aggregation example configured successfully")
message(STATUS "   - 3 targets will be packaged into 'mylib' export")
message(STATUS "   - Generated config will contain fmt, spdlog, and cxxopts dependencies")
