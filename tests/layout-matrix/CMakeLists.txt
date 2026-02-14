cmake_minimum_required(VERSION 3.25)

project(
  layout_matrix_fixture
  VERSION 1.0.0
  LANGUAGES CXX)

if(NOT DEFINED TIP_REPO_ROOT)
  message(FATAL_ERROR "TIP_REPO_ROOT must be provided to layout-matrix fixture")
endif()

if(NOT DEFINED TIP_LAYOUT)
  set(TIP_LAYOUT "fhs")
endif()

string(TOLOWER "${TIP_LAYOUT}" TIP_LAYOUT)
if(NOT TIP_LAYOUT STREQUAL "fhs"
   AND NOT TIP_LAYOUT STREQUAL "split_debug"
   AND NOT TIP_LAYOUT STREQUAL "split_all")
  message(FATAL_ERROR "Invalid TIP_LAYOUT='${TIP_LAYOUT}'. Expected one of: fhs, split_debug, split_all")
endif()

include("${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake")
include("${TIP_REPO_ROOT}/cmake/project_log.cmake")
include("${TIP_REPO_ROOT}/target_install_package.cmake")

set(TIP_INSTALL_LAYOUT
    "${TIP_LAYOUT}"
    CACHE STRING "Install layout for test fixture" FORCE)

add_library(layout_dynamic SHARED src/layout_dynamic.cpp)
target_sources(layout_dynamic PUBLIC FILE_SET HEADERS BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include" FILES "include/layout/layout.hpp")
target_compile_features(layout_dynamic PUBLIC cxx_std_17)
if(WIN32)
  set_target_properties(layout_dynamic PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
endif()
target_install_package(layout_dynamic EXPORT_NAME layout_matrix COMPONENT "Layout")

add_library(layout_archive STATIC src/layout_archive.cpp)
target_compile_features(layout_archive PUBLIC cxx_std_17)
target_install_package(layout_archive EXPORT_NAME layout_matrix COMPONENT "Layout")

add_executable(layout_runner src/layout_runner.cpp)
target_link_libraries(layout_runner PRIVATE layout_archive)
target_compile_features(layout_runner PRIVATE cxx_std_17)
target_install_package(layout_runner EXPORT_NAME layout_matrix COMPONENT "Layout")
