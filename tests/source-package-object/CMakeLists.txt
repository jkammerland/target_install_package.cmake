cmake_minimum_required(VERSION 3.25)

project(
  source_package_object_fixture
  VERSION 1.0.0
  LANGUAGES CXX)

if(NOT DEFINED TIP_REPO_ROOT)
  message(FATAL_ERROR "TIP_REPO_ROOT must be provided to source-package-object fixture")
endif()

include("${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake")
include("${TIP_REPO_ROOT}/cmake/project_log.cmake")
include("${TIP_REPO_ROOT}/target_install_package.cmake")

add_library(source_objects OBJECT)
target_sources(
  source_objects
  PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src/source_objects.cpp"
  PUBLIC FILE_SET
         HEADERS
         BASE_DIRS
         "${CMAKE_CURRENT_SOURCE_DIR}/include"
         FILES
         "include/source_objects/value.hpp")
target_compile_features(source_objects PUBLIC cxx_std_17)

target_install_package(
  source_objects
  NAMESPACE
  SourceObjects::
  INCLUDE_SOURCES
  EXCLUSIVE)
