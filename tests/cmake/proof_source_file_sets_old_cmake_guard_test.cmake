cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()
if(CMAKE_VERSION VERSION_GREATER_EQUAL "4.4")
  _tip_proof_fail("proof_source_file_sets_old_cmake_guard requires CMake older than 4.4")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/source-file-sets-old-cmake-guard")
set(_tip_source_dir "${_tip_case_root}/src")
set(_tip_build_dir "${_tip_case_root}/build")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}")
file(WRITE "${_tip_source_dir}/source.cpp.in" "int configured_source() { return 42; }\n")
file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n" "project(proof_source_old_cmake_guard LANGUAGES CXX)\n" "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n" "add_library(source_only INTERFACE)\n" "target_configure_sources(source_only INTERFACE TYPE SOURCES FILES source.cpp.in)\n")

_tip_proof_append_toolchain_args(_tip_toolchain_args)
_tip_proof_expect_failure(
  NAME
  "configured-source-on-old-cmake"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_source_dir}"
  -B
  "${_tip_build_dir}"
  ${_tip_toolchain_args}
  EXPECT_CONTAINS
  "SOURCES requires CMake 4.4 or newer")

message(STATUS "[proof] CMake 4.4 source file set old-CMake guard proof passed.")
