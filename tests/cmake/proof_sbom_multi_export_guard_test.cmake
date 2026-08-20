cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()
if(NOT DEFINED TIP_SBOM_EXPERIMENTAL_VALUE OR TIP_SBOM_EXPERIMENTAL_VALUE STREQUAL "")
  _tip_proof_fail("TIP_SBOM_EXPERIMENTAL_VALUE is required")
endif()
if(CMAKE_VERSION VERSION_LESS "4.3" OR CMAKE_VERSION VERSION_GREATER_EQUAL "4.4")
  _tip_proof_fail("proof_sbom_multi_export_guard requires CMake 4.3.x")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/sbom-multi-export-guard")
set(_tip_source_dir "${_tip_case_root}/src")
set(_tip_build_dir "${_tip_case_root}/build")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}")

file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.3)\n"
  "project(proof_sbom_multi_export_guard VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(CMAKE_EXPERIMENTAL_GENERATE_SBOM \"${TIP_SBOM_EXPERIMENTAL_VALUE}\")\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(first INTERFACE)\n"
  "target_install_package(first EXPORT_NAME first_export VERSION 1.0.0 SBOM SBOM_NAME Combined SBOM_NO_PROJECT_METADATA)\n"
  "add_library(second INTERFACE)\n"
  "target_install_package(second EXPORT_NAME second_export VERSION 1.0.0 SBOM SBOM_NAME Combined SBOM_NO_PROJECT_METADATA)\n")

_tip_proof_append_toolchain_args(_tip_toolchain_args)
_tip_proof_expect_failure(
  NAME
  "multi-export-on-cmake-43"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_source_dir}"
  -B
  "${_tip_build_dir}"
  ${_tip_toolchain_args}
  EXPECT_CONTAINS
  "sets into one SBOM requires CMake 4.4 or newer")

set(_tip_package_url_source_dir "${_tip_case_root}/package-url-src")
set(_tip_package_url_build_dir "${_tip_case_root}/package-url-build")
file(MAKE_DIRECTORY "${_tip_package_url_source_dir}")
file(
  WRITE "${_tip_package_url_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.3)\n"
  "project(proof_sbom_package_url_guard VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(CMAKE_EXPERIMENTAL_GENERATE_SBOM \"${TIP_SBOM_EXPERIMENTAL_VALUE}\")\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(package_url INTERFACE)\n"
  "target_install_package(package_url VERSION 1.0.0 SBOM SBOM_NO_PROJECT_METADATA SBOM_PACKAGE_URL \"pkg:generic/package-url@1.0.0\")\n")
_tip_proof_expect_failure(
  NAME
  "package-url-on-cmake-43"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_package_url_source_dir}"
  -B
  "${_tip_package_url_build_dir}"
  ${_tip_toolchain_args}
  EXPECT_CONTAINS
  "4.4 or newer because CMake 4.3 does not accept PACKAGE_URL")

message(STATUS "[proof] CMake 4.3 multi-export SBOM guard proof passed.")
