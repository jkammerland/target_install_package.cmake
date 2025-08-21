cmake_minimum_required(VERSION 3.23)
project(custom_alias_example VERSION 1.0.0)

# Include target_install_package utilities
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include(../../CMakeLists.txt)

# Create a library with an underscore in its name
add_library(cbor_tags STATIC)
target_compile_features(cbor_tags PUBLIC cxx_std_17)

target_sources(
  cbor_tags
  PRIVATE src/cbor_tags.cpp
  PUBLIC FILE_SET
         HEADERS
         BASE_DIRS
         include
         FILES
         include/cbor_tags/tags.h
         include/cbor_tags/parser.h)

# Install with custom alias name This will export the target as cbor::tags instead of cbor_tags::cbor_tags
target_install_package(
  cbor_tags
  NAMESPACE
  cbor::
  ALIAS_NAME
  tags
  VERSION
  ${PROJECT_VERSION})

# Another example: library with version suffix
add_library(json_parser_v2 SHARED)
target_compile_features(json_parser_v2 PUBLIC cxx_std_17)
set_target_properties(
  json_parser_v2
  PROPERTIES POSITION_INDEPENDENT_CODE ON
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})
if(WIN32)
  set_target_properties(json_parser_v2 PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()

target_sources(
  json_parser_v2
  PRIVATE src/json_parser.cpp
  PUBLIC FILE_SET
         HEADERS
         BASE_DIRS
         include
         FILES
         include/json_parser/parser.h
         include/json_parser/utils.h)

# Install with cleaner alias Consumer will use json::parser instead of json_parser_v2::json_parser_v2
target_install_package(
  json_parser_v2
  NAMESPACE
  json::
  ALIAS_NAME
  parser
  VERSION
  ${PROJECT_VERSION})

# Example with multi-target export sharing same namespace
add_library(data_core STATIC)
target_compile_features(data_core PUBLIC cxx_std_17)

target_sources(
  data_core
  PRIVATE src/data_core.cpp
  PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/data/core.h)

add_library(data_utils STATIC)
target_sources(
  data_utils
  PRIVATE src/data_utils.cpp
  PUBLIC FILE_SET HEADERS BASE_DIRS include FILES include/data/utils.h)
target_compile_features(data_utils PUBLIC cxx_std_17)

# Both libraries export to same package with custom aliases
target_install_package(
  data_core
  EXPORT_NAME
  data_package
  NAMESPACE
  data::
  ALIAS_NAME
  core)

target_install_package(
  data_utils
  EXPORT_NAME
  data_package
  NAMESPACE
  data::
  ALIAS_NAME
  utils)
