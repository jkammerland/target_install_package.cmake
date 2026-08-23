cmake_minimum_required(VERSION 4.4)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/source-file-set-failures")
set(_tip_direct_cps_source_dir "${_tip_case_root}/direct-cps-src")
set(_tip_direct_cps_build_dir "${_tip_case_root}/direct-cps-build")
set(_tip_direct_cps_install_prefix "${_tip_case_root}/direct-cps-install")
set(_tip_direct_cps_consumer_source_dir "${_tip_case_root}/direct-cps-consumer-src")
set(_tip_direct_cps_consumer_build_dir "${_tip_case_root}/direct-cps-consumer-build")
set(_tip_cps_source_dir "${_tip_case_root}/cps-src")
set(_tip_cps_build_dir "${_tip_case_root}/cps-build")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_direct_cps_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_cps_source_dir}/src")
file(WRITE "${_tip_direct_cps_source_dir}/src/source.cpp" "int source_value() { return 42; }\n")
file(WRITE "${_tip_cps_source_dir}/src/source.cpp" "int source_value() { return 42; }\n")
file(
  WRITE "${_tip_direct_cps_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.4)\n"
  "project(proof_direct_source_cps_failure VERSION 1.0.0 LANGUAGES CXX)\n"
  "add_library(source_only INTERFACE)\n"
  "target_sources(source_only INTERFACE FILE_SET implementation TYPE SOURCES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/src/source.cpp\")\n"
  "install(TARGETS source_only EXPORT source_cps FILE_SET implementation DESTINATION share/source_cps/src)\n"
  "install(PACKAGE_INFO source_cps EXPORT source_cps NO_PROJECT_METADATA DESTINATION share/cps/source_cps)\n")
file(
  WRITE "${_tip_cps_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.4)\n"
  "project(proof_source_cps_failure VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(source_only INTERFACE)\n"
  "target_sources(source_only INTERFACE FILE_SET implementation TYPE SOURCES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/src/source.cpp\")\n"
  "target_install_package(source_only EXPORT_NAME source_cps CPS CPS_NO_PROJECT_METADATA VERSION 1.0.0)\n")

_tip_proof_append_toolchain_args(_tip_toolchain_args)
_tip_proof_run_step(
  NAME
  "direct-cmake-cps-source-set-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_direct_cps_source_dir}"
  -B
  "${_tip_direct_cps_build_dir}"
  ${_tip_toolchain_args})
_tip_proof_run_step(
  NAME
  "direct-cmake-cps-source-set-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_direct_cps_build_dir}"
  --prefix
  "${_tip_direct_cps_install_prefix}")
set(_tip_direct_cps_file "${_tip_direct_cps_install_prefix}/share/cps/source_cps/source_cps.cps")
_tip_proof_assert_exists("${_tip_direct_cps_install_prefix}/share/source_cps/src/source.cpp")
_tip_proof_assert_file_not_contains("${_tip_direct_cps_file}" "source.cpp")
_tip_proof_assert_file_not_contains("${_tip_direct_cps_file}" "SOURCES")

file(MAKE_DIRECTORY "${_tip_direct_cps_consumer_source_dir}")
file(
  WRITE "${_tip_direct_cps_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.4)\n"
  "project(proof_direct_source_cps_consumer LANGUAGES CXX)\n"
  "find_package(source_cps CONFIG REQUIRED PATHS \"${_tip_direct_cps_install_prefix}\" NO_DEFAULT_PATH)\n"
  "if(NOT source_cps_CONFIG MATCHES \"/cps/\")\n"
  "  message(FATAL_ERROR \"Expected CPS package file, got: \${source_cps_CONFIG}\")\n"
  "endif()\n"
  "if(NOT TARGET source_cps::source_only)\n"
  "  message(FATAL_ERROR \"Missing CPS imported target\")\n"
  "endif()\n"
  "add_executable(proof_direct_source_cps_consumer main.cpp)\n"
  "target_link_libraries(proof_direct_source_cps_consumer PRIVATE source_cps::source_only)\n")
file(WRITE "${_tip_direct_cps_consumer_source_dir}/main.cpp" "int source_value();\nint main() { return source_value() == 42 ? 0 : 1; }\n")
_tip_proof_run_step(
  NAME
  "direct-cmake-cps-source-set-consumer-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_direct_cps_consumer_source_dir}"
  -B
  "${_tip_direct_cps_consumer_build_dir}"
  ${_tip_toolchain_args})
_tip_proof_expect_failure(
  NAME
  "direct-cmake-cps-source-set-consumer-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_direct_cps_consumer_build_dir}"
  EXPECT_CONTAINS
  "source_value")
_tip_proof_expect_failure(
  NAME
  "cps-source-set-rejection"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_cps_source_dir}"
  -B
  "${_tip_cps_build_dir}"
  ${_tip_toolchain_args}
  EXPECT_CONTAINS
  "does not support SOURCES file sets")

function(_tip_write_source_file_set_hygiene_fixture name expected_message)
  set(_tip_fixture_dir "${_tip_case_root}/${name}")
  file(MAKE_DIRECTORY "${_tip_fixture_dir}/include/proof" "${_tip_fixture_dir}/src")
  file(WRITE "${_tip_fixture_dir}/include/proof/source.hpp" "#pragma once\n")
  file(WRITE "${_tip_fixture_dir}/src/source.cpp" "int source_value() { return 42; }\n")
  string(JOIN " " _tip_source_file_set_properties ${ARGN})
  file(
    WRITE "${_tip_fixture_dir}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 4.4)\n"
    "project(proof_source_file_set_hygiene_failure VERSION 1.0.0 LANGUAGES CXX)\n"
    "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
    "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
    "add_library(source_only INTERFACE)\n"
    "target_sources(source_only INTERFACE FILE_SET api TYPE HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/include/proof/source.hpp\")\n"
    "target_sources(source_only INTERFACE FILE_SET implementation TYPE SOURCES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/src/source.cpp\")\n"
    "target_install_package(source_only EXPORT_NAME ${name} SOURCE_FILE_SET_PROPERTIES ${_tip_source_file_set_properties})\n")
  _tip_proof_expect_failure(
    NAME
    "${name}-configure"
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${_tip_fixture_dir}"
    -B
    "${_tip_fixture_dir}/build"
    ${_tip_toolchain_args}
    EXPECT_CONTAINS
    "${expected_message}")
endfunction()

_tip_write_source_file_set_hygiene_fixture(malformed-source-file-set-properties "SOURCE_FILE_SET_PROPERTIES for target 'source_only'" implementation SKIP_LINTING)
_tip_write_source_file_set_hygiene_fixture(unknown-source-file-set-property "UNKNOWN_PROPERTY" implementation UNKNOWN_PROPERTY ON)
_tip_write_source_file_set_hygiene_fixture(header-source-file-set-property "SOURCE_FILE_SET_PROPERTIES file set 'api'" api SKIP_LINTING ON)

message(STATUS "[proof] CMake 4.4 source file set failure proof passed.")
