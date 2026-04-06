cmake_minimum_required(VERSION 3.25)

project(
  source_package_module_library_fixture
  VERSION 1.0.0
  LANGUAGES CXX)

if(NOT DEFINED TIP_REPO_ROOT)
  message(FATAL_ERROR "TIP_REPO_ROOT must be provided to source-package-module-library fixture")
endif()

include("${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake")
include("${TIP_REPO_ROOT}/cmake/project_log.cmake")
include("${TIP_REPO_ROOT}/target_install_package.cmake")

add_library(source_plugin MODULE)
target_sources(source_plugin PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src/source_plugin.cpp")
target_compile_features(source_plugin PUBLIC cxx_std_17)

target_install_package(
  source_plugin
  NAMESPACE
  SourcePlugin::
  INCLUDE_SOURCES
  EXCLUSIVE)
