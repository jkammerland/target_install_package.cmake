cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()
if(CMAKE_VERSION VERSION_LESS "4.3")
  _tip_proof_fail("proof_sbom_missing_gate requires CMake 4.3 or newer and should not be registered on older CMake versions")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/sbom-missing-gate")
set(_tip_source_dir "${_tip_case_root}/fixture-src")
set(_tip_build_dir "${_tip_case_root}/fixture-build")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_sbom_missing_gate VERSION 1.2.3 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(missing_gate_lib STATIC src/lib.cpp)\n"
  "target_install_package(missing_gate_lib EXPORT_NAME MissingGatePkg SBOM)\n")
file(WRITE "${_tip_source_dir}/src/lib.cpp" "int missing_gate_value() { return 1; }\n")

_tip_proof_expect_failure(
  NAME
  "missing-gate-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_source_dir}"
  -B
  "${_tip_build_dir}"
  ${_tip_toolchain_args}
  EXPECT_CONTAINS
  "CMAKE_EXPERIMENTAL_GENERATE_SBOM"
  "activation value for this CMake version")

message(STATUS "[proof] SBOM missing-gate proof passed.")
