cmake_minimum_required(VERSION 3.25)

project(
  target_install_package
  VERSION 7.0.4
  DESCRIPTION "CMake utilities for creating installable packages"
  HOMEPAGE_URL "https://github.com/jkammerland/target_install_package.cmake")

# ~~~
# Project dependencies, these have been included directly in this project for
# ease of installation. They rarely change, and this is the the one repo that requires all of them.
# ~~~
include(${CMAKE_CURRENT_LIST_DIR}/cmake/list_file_include_guard.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/project_include_guard.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/cmake/project_log.cmake)
project_include_guard() # Guard against multiple add_subdirectory (e.g git submodules/inlining/copies)

# ~~~
# This projects cmake functions!
# ~~~
include(${CMAKE_CURRENT_LIST_DIR}/target_configure_sources.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/target_install_package.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/export_cpack.cmake)

# Create an INTERFACE library to represent our modules
add_library(${PROJECT_NAME} INTERFACE)

# Only install if this is the main project or if explicitly enabled
option(TARGET_INSTALL_PACKAGE_ENABLE_INSTALL "Create install configuration for ${PROJECT_NAME}" OFF)
option(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL "FOR CI: Do not create install configuration for ${PROJECT_NAME}" OFF)
option(TARGET_INSTALL_PACKAGE_ENABLE_CPACK "Configure CPack release archives for ${PROJECT_NAME}" OFF)
option(TARGET_INSTALL_PACKAGE_REQUIRE_SIGNING "Require GPG signing for ${PROJECT_NAME} CPack archives" OFF)
set(GPG_SIGNING_KEY
    ""
    CACHE STRING "GPG key fingerprint or key id used to sign CPack archives")
set(GPG_PASSPHRASE_FILE
    ""
    CACHE FILEPATH "File containing the GPG key passphrase for noninteractive CPack signing")
if(NOT TARGET_INSTALL_PACKAGE_DISABLE_INSTALL)
  if(PROJECT_IS_TOP_LEVEL OR TARGET_INSTALL_PACKAGE_ENABLE_INSTALL)
    # Use target_install_package to install itself and target_configure_sources
    target_install_package(
      ${PROJECT_NAME}
      ADDITIONAL_FILES
      ${CMAKE_CURRENT_LIST_DIR}/cmake/generic-config.cmake.in
      ${CMAKE_CURRENT_LIST_DIR}/cmake/sign_packages.cmake.in
      ${CMAKE_CURRENT_LIST_DIR}/cmake/external_container_package.cmake
      ADDITIONAL_FILES_DESTINATION
      ${CMAKE_INSTALL_DATADIR}/cmake/${PROJECT_NAME}
      INCLUDE_ON_FIND_PACKAGE
      ${CMAKE_CURRENT_LIST_DIR}/cmake/list_file_include_guard.cmake
      ${CMAKE_CURRENT_LIST_DIR}/cmake/project_include_guard.cmake
      ${CMAKE_CURRENT_LIST_DIR}/cmake/project_log.cmake
      ${CMAKE_CURRENT_LIST_DIR}/target_configure_sources.cmake
      ${CMAKE_CURRENT_LIST_DIR}/target_install_package.cmake
      ${CMAKE_CURRENT_LIST_DIR}/export_cpack.cmake
      # Use generic-config.cmake.in as the template
      CONFIG_TEMPLATE
      ${CMAKE_CURRENT_LIST_DIR}/cmake/generic-config.cmake.in
      # Set destination to standard CMake modules location
      CMAKE_CONFIG_DESTINATION
      ${CMAKE_INSTALL_DATADIR}/cmake/${PROJECT_NAME}
      # Override include destination to put modules in the cmake dir
      INCLUDE_DESTINATION
      ${CMAKE_INSTALL_DATADIR}/cmake/${PROJECT_NAME})

    install(
      PROGRAMS ${CMAKE_CURRENT_LIST_DIR}/cmake/build_minimal_container.sh ${CMAKE_CURRENT_LIST_DIR}/cmake/collect_runtime_deps.sh ${CMAKE_CURRENT_LIST_DIR}/cmake/container_to_quadlet.sh
      DESTINATION ${CMAKE_INSTALL_DATADIR}/cmake/${PROJECT_NAME}
      COMPONENT Development)
    install(
      FILES ${CMAKE_CURRENT_LIST_DIR}/LICENSE
      DESTINATION ${CMAKE_INSTALL_DATADIR}/doc/${PROJECT_NAME}
      COMPONENT Development)
  endif()
endif()

if(TARGET_INSTALL_PACKAGE_ENABLE_CPACK)
  if(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL)
    message(FATAL_ERROR "TARGET_INSTALL_PACKAGE_ENABLE_CPACK requires install rules; disable TARGET_INSTALL_PACKAGE_DISABLE_INSTALL.")
  endif()

  set(_tip_self_cpack_signing_args GENERATE_CHECKSUMS ON)
  if(TARGET_INSTALL_PACKAGE_REQUIRE_SIGNING
     OR GPG_SIGNING_KEY
     OR (DEFINED ENV{GPG_SIGNING_KEY} AND NOT "$ENV{GPG_SIGNING_KEY}" STREQUAL ""))
    list(APPEND _tip_self_cpack_signing_args SIGNING_METHOD detached)
    if(GPG_SIGNING_KEY)
      list(APPEND _tip_self_cpack_signing_args GPG_SIGNING_KEY "${GPG_SIGNING_KEY}")
    endif()
    if(GPG_PASSPHRASE_FILE)
      list(APPEND _tip_self_cpack_signing_args GPG_PASSPHRASE_FILE "${GPG_PASSPHRASE_FILE}")
    endif()
  endif()

  export_cpack(
    PACKAGE_NAME
    "${PROJECT_NAME}"
    PACKAGE_VERSION
    "${PROJECT_VERSION}"
    PACKAGE_VENDOR
    "jkammerland"
    PACKAGE_CONTACT
    "https://github.com/jkammerland/target_install_package.cmake/issues"
    PACKAGE_DESCRIPTION
    "${PROJECT_DESCRIPTION}"
    PACKAGE_HOMEPAGE_URL
    "${PROJECT_HOMEPAGE_URL}"
    PACKAGE_LICENSE
    "MIT"
    LICENSE_FILE
    "${CMAKE_CURRENT_LIST_DIR}/LICENSE"
    GENERATORS
    TGZ
    ZIP
    ${_tip_self_cpack_signing_args}
    ADDITIONAL_CPACK_VARS
    CPACK_PACKAGE_FILE_NAME
    "${PROJECT_NAME}-${PROJECT_VERSION}-cmake"
    CPACK_SYSTEM_NAME
    "cmake")
endif()

option(${PROJECT_NAME}_BUILD_TESTS "Run the tests" OFF)
if(${PROJECT_NAME}_BUILD_TESTS)
  project_log(VERBOSE "Running standalone, including tests...")
  enable_testing()
  add_subdirectory(tests)
endif()
