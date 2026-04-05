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

add_library(source_math_modules INTERFACE)
target_compile_features(source_math_modules INTERFACE cxx_std_20)

set_target_properties(source_math_modules PROPERTIES CXX_SCAN_FOR_MODULES ON)

if(APPLE AND CMAKE_OSX_SYSROOT)
  target_compile_options(source_math_modules INTERFACE "-isysroot${CMAKE_OSX_SYSROOT}")
endif()

target_install_package(
  source_math_modules
  NAMESPACE
  SourceMathModules::
  VERSION
  ${PROJECT_VERSION}
  INCLUDE_ON_FIND_PACKAGE
  cmake/source_math_modules-modules.cmake
  ADDITIONAL_FILES
  modules/source_math.cppm
  ADDITIONAL_FILES_DESTINATION
  "${CMAKE_INSTALL_INCLUDEDIR}/source_math_modules/modules"
  SOURCE_FILES
  src/source_math.cpp)
