cmake_minimum_required(VERSION 3.25)

project(
  source_package_fixture
  VERSION 1.0.0
  LANGUAGES CXX)

if(NOT DEFINED TIP_REPO_ROOT)
  message(FATAL_ERROR "TIP_REPO_ROOT must be provided to source-package fixture")
endif()

include("${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake")
include("${TIP_REPO_ROOT}/cmake/project_log.cmake")
include("${TIP_REPO_ROOT}/target_install_package.cmake")

add_library(source_package STATIC)

set(_tip_generated_source "${CMAKE_CURRENT_BINARY_DIR}/generated/source_package_generated.cpp")
set(_tip_generated_source_script "${CMAKE_CURRENT_BINARY_DIR}/write_generated_source.cmake")
file(
  WRITE
  "${_tip_generated_source_script}"
  [=[
if(NOT DEFINED OUTPUT)
  message(FATAL_ERROR "OUTPUT is required")
endif()

get_filename_component(_output_dir "${OUTPUT}" DIRECTORY)
file(MAKE_DIRECTORY "${_output_dir}")
file(
  WRITE
  "${OUTPUT}"
  "#ifndef SOURCE_PACKAGE_PRIVATE_VALUE\n#error SOURCE_PACKAGE_PRIVATE_VALUE is required\n#endif\n#ifndef SOURCE_PACKAGE_OPTION_VALUE\n#error SOURCE_PACKAGE_OPTION_VALUE is required\n#endif\n\nint source_package_generated_offset() {\n  return SOURCE_PACKAGE_PRIVATE_VALUE - SOURCE_PACKAGE_OPTION_VALUE;\n}\n")
]=])

add_custom_command(
  OUTPUT generated/source_package_generated.cpp
  COMMAND "${CMAKE_COMMAND}" "-DOUTPUT=${_tip_generated_source}" -P "${_tip_generated_source_script}"
  DEPENDS "${_tip_generated_source_script}"
  VERBATIM)

target_sources(
  source_package
  PRIVATE src/source_package.cpp generated/source_package_generated.cpp
  PUBLIC FILE_SET
         HEADERS
         BASE_DIRS
         "${CMAKE_CURRENT_SOURCE_DIR}/include"
         FILES
         "include/source_package/source_package.hpp")
target_compile_definitions(source_package PRIVATE SOURCE_PACKAGE_PRIVATE_VALUE=7)
target_include_directories(source_package PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
if(CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
  target_compile_options(source_package PRIVATE -DSOURCE_PACKAGE_OPTION_VALUE=7)
elseif(MSVC)
  target_compile_options(source_package PRIVATE /DSOURCE_PACKAGE_OPTION_VALUE=7)
endif()
target_compile_features(source_package PUBLIC cxx_std_17)

target_install_package(
  source_package
  NAMESPACE SourcePackage::
  INCLUDE_SOURCES EXCLUSIVE)
