cmake_minimum_required(VERSION 3.25)

project(target_install_package VERSION 5.0.1)

# ~~~
# Project dependencies, these have been included directly in this project for
# ease of installation. They rarely change, and this is the the one repo that requires all of them.
# ~~~
include(${CMAKE_CURRENT_LIST_DIR}/cmake/list_file_include_guard.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/project_include_guard.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/project_log.cmake)
project_include_guard() # Guard against multiple add_subdirectory (e.g git submodules)

# ~~~
# This projects cmake functions!
# ~~~
include(${CMAKE_CURRENT_LIST_DIR}/install_package_helpers.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/target_configure_sources.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/target_install_package.cmake)

# Create an INTERFACE library to represent our modules
add_library(${PROJECT_NAME} INTERFACE)

# Only install if this is the main project or if explicitly enabled
option(TARGET_INSTALL_PACKAGE_ENABLE_INSTALL "Create install configuration for ${PROJECT_NAME}" OFF)
option(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL "Do not create install configuration for ${PROJECT_NAME}" OFF)
if(NOT TARGET_INSTALL_PACKAGE_DISABLE_INSTALL)
  if(${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_SOURCE_DIR} OR TARGET_INSTALL_PACKAGE_ENABLE_INSTALL)
    # Use target_install_package to install itself and target_configure_sources
    target_install_package(
      ${PROJECT_NAME}
      ADDITIONAL_FILES
      ${CMAKE_CURRENT_LIST_DIR}/cmake/generic-config.cmake.in
      ADDITIONAL_FILES_DESTINATION
      "cmake"
      PUBLIC_CMAKE_FILES
      ${CMAKE_CURRENT_LIST_DIR}/cmake/list_file_include_guard.cmake
      ${CMAKE_CURRENT_LIST_DIR}/cmake/project_include_guard.cmake
      ${CMAKE_CURRENT_LIST_DIR}/cmake/project_log.cmake
      ${CMAKE_CURRENT_LIST_DIR}/install_package_helpers.cmake
      ${CMAKE_CURRENT_LIST_DIR}/target_configure_sources.cmake
      ${CMAKE_CURRENT_LIST_DIR}/target_install_package.cmake
      # Use generic-config.cmake.in as the template
      CONFIG_TEMPLATE
      ${CMAKE_CURRENT_LIST_DIR}/cmake/generic-config.cmake.in
      # Set destination to standard CMake modules location
      CMAKE_CONFIG_DESTINATION
      ${CMAKE_INSTALL_DATADIR}/cmake/${PROJECT_NAME}
      # Override include destination to put modules in the cmake dir
      INCLUDE_DESTINATION
      ${CMAKE_INSTALL_DATADIR}/cmake/${PROJECT_NAME}
      RUNTIME_COMPONENT
      "CMakeUtilities"
      DEVELOPMENT_COMPONENT
      "CMakeUtilities")
  endif()
endif()

option(${PROJECT_NAME}_BUILD_TESTS "Run the tests" OFF)
if(${PROJECT_NAME}_BUILD_TESTS)
  project_log(VERBOSE "Running standalone, including tests...")
  add_subdirectory(tests)
endif()
