cmake_minimum_required(VERSION 4.4)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/osef")
file(REMOVE_RECURSE "${_tip_case_root}")

function(_tip_write_ordinary_source_extraction_fixture name expected_message source_declaration)
  if(ARGC GREATER 3)
    set(_tip_target_declaration "${ARGV3}")
  else()
    set(_tip_target_declaration "add_library(ordinary_source_only INTERFACE)")
  endif()
  string(SHA256 _tip_fixture_hash "${name}")
  string(SUBSTRING "${_tip_fixture_hash}" 0 8 _tip_fixture_hash)
  set(_tip_fixture_dir "${_tip_case_root}/${_tip_fixture_hash}")
  file(MAKE_DIRECTORY "${_tip_fixture_dir}/include/proof" "${_tip_fixture_dir}/src")
  file(WRITE "${_tip_fixture_dir}/include/proof/ordinary.hpp" "#pragma once\n")
  file(WRITE "${_tip_fixture_dir}/src/ordinary.cpp" "int ordinary_value() { return 42; }\n")
  file(
    WRITE "${_tip_fixture_dir}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 4.4)\n"
    "project(proof_ordinary_source_extraction_failure VERSION 1.0.0 LANGUAGES CXX)\n"
    "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
    "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
    "${_tip_target_declaration}\n"
    "${source_declaration}\n"
    "target_install_package(ordinary_source_only EXPORT_NAME ${name} SOURCE_FILE_SET_FROM_TARGET_SOURCES implementation)\n")
  _tip_proof_expect_failure(
    NAME
    "${name}-configure"
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${_tip_fixture_dir}"
    -B
    "${_tip_fixture_dir}/build"
    EXPECT_CONTAINS
    "${expected_message}")
endfunction()

_tip_write_ordinary_source_extraction_fixture(generator-expression-source "cannot extract generator expression" "target_sources(ordinary_source_only INTERFACE \"\$<\$<BOOL:1>:src/ordinary.cpp>\")")
_tip_write_ordinary_source_extraction_fixture(
  duplicate-source
  "already in an explicit source file set"
  "target_sources(ordinary_source_only INTERFACE src/ordinary.cpp)\ntarget_sources(ordinary_source_only INTERFACE FILE_SET explicit_implementation TYPE SOURCES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/src/ordinary.cpp\")"
)
_tip_write_ordinary_source_extraction_fixture(header-source "is a header" "target_sources(ordinary_source_only INTERFACE include/proof/ordinary.hpp)")
_tip_write_ordinary_source_extraction_fixture(binary-library "supports INTERFACE_LIBRARY targets only" "target_sources(ordinary_source_only PRIVATE src/ordinary.cpp)"
                                              "add_library(ordinary_source_only STATIC)")

message(STATUS "[proof] Ordinary source extraction failure proof passed.")
