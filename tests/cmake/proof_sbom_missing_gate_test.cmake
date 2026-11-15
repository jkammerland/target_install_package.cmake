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
set(_tip_install_prefix "${_tip_case_root}/fixture-install")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

# CMake 4.3 and 4.4 only provide install(SBOM) behind an experiment, so a missing activation value must fail clearly.
if(CMAKE_VERSION VERSION_LESS "4.5")
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
  return()
endif()

# CMake 4.5 provides install(SBOM) without an experiment. One export's directory keeps a CMake 4.4
# activation value and the other has none; the aggregated SBOM must not treat that as conflicting metadata.
file(MAKE_DIRECTORY "${_tip_source_dir}/gateless/src" "${_tip_source_dir}/stale-gate/src")
file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_sbom_missing_gate VERSION 1.2.3 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_subdirectory(gateless)\n"
  "add_subdirectory(stale-gate)\n")
file(
  WRITE "${_tip_source_dir}/gateless/CMakeLists.txt"
  "add_library(gateless_lib STATIC src/lib.cpp)\n"
  "target_install_package(gateless_lib EXPORT_NAME GatelessExport VERSION 1.2.3 SBOM SBOM_NAME MissingGatePkg SBOM_NO_PROJECT_METADATA SBOM_DESTINATION \"share/sbom/missinggate\")\n")
file(
  WRITE "${_tip_source_dir}/stale-gate/CMakeLists.txt"
  "set(CMAKE_EXPERIMENTAL_GENERATE_SBOM \"2d856d6d-53e8-488b-a17f-d486d2cac317\")\n"
  "add_library(stale_gate_lib STATIC src/lib.cpp)\n"
  "target_install_package(stale_gate_lib EXPORT_NAME StaleGateExport VERSION 1.2.3 SBOM SBOM_NAME MissingGatePkg SBOM_NO_PROJECT_METADATA SBOM_DESTINATION \"share/sbom/missinggate\")\n")
file(WRITE "${_tip_source_dir}/gateless/src/lib.cpp" "int gateless_value() { return 1; }\n")
file(WRITE "${_tip_source_dir}/stale-gate/src/lib.cpp" "int stale_gate_value() { return 2; }\n")

_tip_proof_run_step(
  NAME
  "gateless-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_source_dir}"
  -B
  "${_tip_build_dir}"
  "-DCMAKE_BUILD_TYPE=Release"
  ${_tip_toolchain_args})
_tip_proof_run_step(
  NAME
  "gateless-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_build_dir}"
  --config
  Release)
_tip_proof_run_step(
  NAME
  "gateless-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build_dir}"
  --config
  Release
  --prefix
  "${_tip_install_prefix}")

_tip_proof_sbom_file(_tip_sbom_file "${_tip_install_prefix}/share/sbom/missinggate" "MissingGatePkg" "Release")
_tip_proof_find_spdx_document("${_tip_sbom_file}" "MissingGatePkg" _tip_document_index)
_tip_proof_assert_root_element_names("${_tip_sbom_file}" "${_tip_document_index}" gateless_lib stale_gate_lib)

message(STATUS "[proof] SBOM missing-gate proof passed.")
