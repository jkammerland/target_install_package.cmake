cmake_minimum_required(VERSION 3.25)

project(
  source_package_modules_fixture
  VERSION 1.0.0
  LANGUAGES CXX)

if(NOT DEFINED TIP_REPO_ROOT)
  message(FATAL_ERROR "TIP_REPO_ROOT must be provided to source-package-modules fixture")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include("${TIP_REPO_ROOT}/examples/check_cxx_modules_support.cmake")
check_cxx_modules_support(modules_supported)
if(NOT modules_supported)
  message(FATAL_ERROR "source-package-modules fixture requires C++ modules support")
endif()

include("${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake")
include("${TIP_REPO_ROOT}/cmake/project_log.cmake")
include("${TIP_REPO_ROOT}/target_install_package.cmake")

add_library(source_math_modules STATIC)
target_sources(
  source_math_modules
  PRIVATE src/source_math.cpp
  PUBLIC FILE_SET
         CXX_MODULES
         TYPE
         CXX_MODULES
         BASE_DIRS
         "${CMAKE_CURRENT_SOURCE_DIR}/modules"
         FILES
         "modules/source_math.cppm")
target_compile_features(source_math_modules PUBLIC cxx_std_20)
set_target_properties(source_math_modules PROPERTIES CXX_SCAN_FOR_MODULES ON)

if(APPLE AND CMAKE_OSX_SYSROOT)
  target_compile_options(source_math_modules PUBLIC "-isysroot${CMAKE_OSX_SYSROOT}")
endif()

target_install_package(
  source_math_modules
  NAMESPACE
  SourceMathModules::
  VERSION
  ${PROJECT_VERSION}
  MODULE_DESTINATION
  "${CMAKE_INSTALL_INCLUDEDIR}/source_math_modules/modules"
  INCLUDE_SOURCES
  EXCLUSIVE)
