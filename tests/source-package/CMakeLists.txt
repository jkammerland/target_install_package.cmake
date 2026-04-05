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

add_library(source_package INTERFACE)
target_sources(
  source_package
  INTERFACE FILE_SET
            HEADERS
            BASE_DIRS
            "${CMAKE_CURRENT_SOURCE_DIR}/include"
            FILES
            "include/source_package/source_package.hpp")
target_compile_features(source_package INTERFACE cxx_std_17)

target_install_package(
  source_package
  NAMESPACE SourcePackage::
  SOURCE_FILES
  src/source_package.cpp)
