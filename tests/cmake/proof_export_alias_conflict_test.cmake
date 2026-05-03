cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/export-alias-conflict")
set(_tip_source_dir "${_tip_case_root}/fixture-src")
set(_tip_build_dir "${_tip_case_root}/fixture-build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_export_alias_conflict LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(alias_a STATIC src/a.cpp)\n"
  "add_library(alias_b STATIC src/b.cpp)\n"
  "target_install_package(alias_a EXPORT_NAME AliasConflict NAMESPACE Alias:: ALIAS_NAME core)\n"
  "target_install_package(alias_b EXPORT_NAME AliasConflict NAMESPACE Alias:: ALIAS_NAME core)\n")
file(WRITE "${_tip_source_dir}/src/a.cpp" "int alias_a_value() { return 1; }\n")
file(WRITE "${_tip_source_dir}/src/b.cpp" "int alias_b_value() { return 2; }\n")

set(_tip_configure_command "${CMAKE_COMMAND}" -S "${_tip_source_dir}" -B "${_tip_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_expect_failure(
  NAME
  "alias-conflict-configure"
  COMMAND
  ${_tip_configure_command}
  EXPECT_CONTAINS
  "Duplicate exported target name"
  "Use unique ALIAS_NAME values")

message(STATUS "[proof] Export alias conflict proof passed.")
