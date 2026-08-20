cmake_minimum_required(VERSION 4.4)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/source-file-set-failures")
set(_tip_cps_source_dir "${_tip_case_root}/cps-src")
set(_tip_cps_build_dir "${_tip_case_root}/cps-build")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_cps_source_dir}/src")
file(WRITE "${_tip_cps_source_dir}/src/source.cpp" "int source_value() { return 42; }\n")
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
  "is not supported with SOURCES file sets")

message(STATUS "[proof] CMake 4.4 source file set failure proof passed.")
