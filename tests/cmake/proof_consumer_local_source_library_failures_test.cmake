cmake_minimum_required(VERSION 4.4)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cslf")
file(REMOVE_RECURSE "${_tip_case_root}")

function(_tip_write_consumer_local_failure_fixture name expected_message target_declaration body)
  string(SHA256 _tip_fixture_hash "${name}")
  string(SUBSTRING "${_tip_fixture_hash}" 0 8 _tip_fixture_hash)
  set(_tip_fixture_dir "${_tip_case_root}/${_tip_fixture_hash}")
  file(MAKE_DIRECTORY "${_tip_fixture_dir}/src")
  file(WRITE "${_tip_fixture_dir}/src/source.cpp" "int value() { return 1; }\n")
  file(
    WRITE "${_tip_fixture_dir}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 4.4)\n"
    "project(proof_consumer_local_source_failure LANGUAGES CXX)\n"
    "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
    "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
    "${target_declaration}\n"
    "${body}\n"
    "target_install_package(source_target EXPORT_NAME ${name} SOURCE_LIBRARY_TYPE STATIC)\n")
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

_tip_write_consumer_local_failure_fixture(no-source-set "requires an INTERFACE SOURCES file set" "add_library(source_target INTERFACE)" "")
_tip_write_consumer_local_failure_fixture(
  generator-expression-private-definition
  "does not support generator expressions"
  "add_library(source_target STATIC)"
  "target_sources(source_target PUBLIC FILE_SET implementation TYPE SOURCES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/src/source.cpp\")\ntarget_compile_definitions(source_target PRIVATE \"\$<\$<BOOL:1>:VALUE=1>\")"
)
_tip_write_consumer_local_failure_fixture(
  non-relocatable-private-include
  "cannot relocate INCLUDE_DIRECTORIES"
  "add_library(source_target STATIC)"
  "target_sources(source_target PUBLIC FILE_SET implementation TYPE SOURCES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/src/source.cpp\")\ntarget_include_directories(source_target PRIVATE \"\${CMAKE_CURRENT_SOURCE_DIR}/src\")"
)

set(_tip_alias_only_fixture_dir "${_tip_case_root}/alias-without-type")
file(MAKE_DIRECTORY "${_tip_alias_only_fixture_dir}")
file(WRITE "${_tip_alias_only_fixture_dir}/CMakeLists.txt"
     "cmake_minimum_required(VERSION 4.4)\n" "project(proof_consumer_local_source_alias LANGUAGES NONE)\n" "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
     "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n" "add_library(source_target INTERFACE)\n" "target_install_package(source_target SOURCE_LIBRARY_ALIAS compiled)\n")
_tip_proof_expect_failure(
  NAME
  "alias-without-type-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_alias_only_fixture_dir}"
  -B
  "${_tip_alias_only_fixture_dir}/build"
  EXPECT_CONTAINS
  "SOURCE_LIBRARY_ALIAS")

message(STATUS "[proof] Consumer-local source library failure proof passed.")
