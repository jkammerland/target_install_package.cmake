cmake_minimum_required(VERSION 3.28)

project(source_package_modules_example VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(../check_cxx_modules_support.cmake)
check_cxx_modules_support(modules_supported)
if(NOT modules_supported)
  return()
endif()

set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/load_target_install_package.cmake)

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
