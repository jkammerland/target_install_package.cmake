cmake_minimum_required(VERSION 3.25)

project(
  component_dependencies_fixture
  VERSION 1.0.0
  LANGUAGES CXX)

if(NOT DEFINED TIP_REPO_ROOT)
  message(FATAL_ERROR "TIP_REPO_ROOT must be provided to component-dependencies fixture")
endif()

include("${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake")
include("${TIP_REPO_ROOT}/cmake/project_log.cmake")
include("${TIP_REPO_ROOT}/target_install_package.cmake")

add_library(component_base STATIC src/component_base.cpp)
target_compile_features(component_base PUBLIC cxx_std_17)
target_install_package(
  component_base
  EXPORT_NAME
  component_deps_fixture
  NAMESPACE
  ComponentDeps::
  COMPONENT_DEPENDENCIES
  graphics
  "DepA REQUIRED")

add_library(component_tools STATIC src/component_tools.cpp)
target_compile_features(component_tools PUBLIC cxx_std_17)
target_install_package(
  component_tools
  EXPORT_NAME
  component_deps_fixture
  NAMESPACE
  ComponentDeps::
  COMPONENT_DEPENDENCIES
  graphics
  "DepB REQUIRED")
