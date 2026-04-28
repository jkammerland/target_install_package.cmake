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
if(CMAKE_VERSION VERSION_LESS "4.3")
  _tip_proof_fail("proof_sbom_metadata_conflict requires CMake 4.3 or newer and should not be registered on older CMake versions")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/sbom-metadata-conflict")

file(REMOVE_RECURSE "${_tip_case_root}")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

function(_tip_proof_write_conflict_fixture case_name first_install second_install)
  set(_tip_first_project "FirstProject")
  set(_tip_second_project "SecondProject")
  if(ARGC GREATER 3)
    set(_tip_first_project "${ARGV3}")
  endif()
  if(ARGC GREATER 4)
    set(_tip_second_project "${ARGV4}")
  endif()

  set(_tip_source_dir "${_tip_case_root}/${case_name}-src")
  set(_tip_build_dir "${_tip_case_root}/${case_name}-build")

  file(MAKE_DIRECTORY "${_tip_source_dir}/first/src")
  file(MAKE_DIRECTORY "${_tip_source_dir}/second/src")

  file(
    WRITE "${_tip_source_dir}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 3.25)\n"
    "project(proof_sbom_metadata_conflict_root VERSION 1.2.3 LANGUAGES CXX)\n"
    "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
    "add_subdirectory(first)\n"
    "add_subdirectory(second)\n")

  file(
    WRITE "${_tip_source_dir}/first/CMakeLists.txt"
    "project(${_tip_first_project} VERSION 1.2.3 SPDX_LICENSE \"MIT\" DESCRIPTION \"First project metadata\" HOMEPAGE_URL \"https://example.invalid/first\" LANGUAGES CXX)\n"
    "set(CMAKE_EXPERIMENTAL_GENERATE_SBOM \"${TIP_SBOM_EXPERIMENTAL_VALUE}\")\n"
    "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
    "add_library(first_lib STATIC src/first.cpp)\n"
    "${first_install}\n")
  file(WRITE "${_tip_source_dir}/first/src/first.cpp" "int first_lib_value() { return 1; }\n")

  file(
    WRITE "${_tip_source_dir}/second/CMakeLists.txt"
    "project(${_tip_second_project} VERSION 1.2.3 SPDX_LICENSE \"Apache-2.0\" DESCRIPTION \"Second project metadata\" HOMEPAGE_URL \"https://example.invalid/second\" LANGUAGES CXX)\n"
    "set(CMAKE_EXPERIMENTAL_GENERATE_SBOM \"${TIP_SBOM_EXPERIMENTAL_VALUE}\")\n"
    "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
    "add_library(second_lib STATIC src/second.cpp)\n"
    "${second_install}\n")
  file(WRITE "${_tip_source_dir}/second/src/second.cpp" "int second_lib_value() { return 2; }\n")

  _tip_proof_expect_failure(
    NAME
    "${case_name}-configure"
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${_tip_source_dir}"
    -B
    "${_tip_build_dir}"
    "-DCMAKE_BUILD_TYPE=Release"
    ${_tip_toolchain_args}
    EXPECT_CONTAINS
    "Conflicting SBOM metadata inheritance mode"
    "SharedConflictExport")
endfunction()

_tip_proof_write_conflict_fixture(
  "inherit-then-none"
  "target_install_package(first_lib EXPORT_NAME SharedConflictExport VERSION 1.2.3 SBOM SBOM_NAME FirstProject SBOM_DESTINATION \"share/sbom/conflict\")"
  "target_install_package(second_lib EXPORT_NAME SharedConflictExport VERSION 1.2.3 SBOM SBOM_NAME FirstProject SBOM_NO_PROJECT_METADATA SBOM_DESTINATION \"share/sbom/conflict\")")

_tip_proof_write_conflict_fixture(
  "none-then-inherit"
  "target_install_package(first_lib EXPORT_NAME SharedConflictExport VERSION 1.2.3 SBOM SBOM_NAME SecondProject SBOM_NO_PROJECT_METADATA SBOM_DESTINATION \"share/sbom/conflict\")"
  "target_install_package(second_lib EXPORT_NAME SharedConflictExport VERSION 1.2.3 SBOM SBOM_NAME SecondProject SBOM_DESTINATION \"share/sbom/conflict\")")

_tip_proof_write_conflict_fixture(
  "project-a-then-project-b"
  "target_install_package(first_lib EXPORT_NAME SharedConflictExport VERSION 1.2.3 SBOM SBOM_NAME SharedProjectConflict SBOM_PROJECT FirstProject SBOM_DESTINATION \"share/sbom/conflict\")"
  "target_install_package(second_lib EXPORT_NAME SharedConflictExport VERSION 1.2.3 SBOM SBOM_NAME SharedProjectConflict SBOM_PROJECT SecondProject SBOM_DESTINATION \"share/sbom/conflict\")")

_tip_proof_write_conflict_fixture(
  "project-b-then-project-a"
  "target_install_package(first_lib EXPORT_NAME SharedConflictExport VERSION 1.2.3 SBOM SBOM_NAME SharedProjectConflict SBOM_PROJECT SecondProject SBOM_DESTINATION \"share/sbom/conflict\")"
  "target_install_package(second_lib EXPORT_NAME SharedConflictExport VERSION 1.2.3 SBOM SBOM_NAME SharedProjectConflict SBOM_PROJECT FirstProject SBOM_DESTINATION \"share/sbom/conflict\")"
  "SecondProject"
  "FirstProject")

_tip_proof_write_conflict_fixture(
  "inherit-then-explicit"
  "target_install_package(first_lib EXPORT_NAME SharedConflictExport VERSION 1.2.3 SBOM SBOM_NAME FirstProject SBOM_DESTINATION \"share/sbom/conflict\")"
  "target_install_package(second_lib EXPORT_NAME SharedConflictExport VERSION 1.2.3 SBOM SBOM_NAME FirstProject SBOM_DESTINATION \"share/sbom/conflict\")")

_tip_proof_write_conflict_fixture(
  "explicit-then-inherit"
  "target_install_package(first_lib EXPORT_NAME SharedConflictExport VERSION 1.2.3 SBOM SBOM_NAME SecondProject SBOM_DESTINATION \"share/sbom/conflict\")"
  "target_install_package(second_lib EXPORT_NAME SharedConflictExport VERSION 1.2.3 SBOM SBOM_NAME SecondProject SBOM_DESTINATION \"share/sbom/conflict\")")

message(STATUS "[proof] SBOM metadata conflict proof passed.")
