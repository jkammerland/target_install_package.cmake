cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/substitution-mode-variables")
set(_tip_source_dir "${_tip_case_root}/source")
set(_tip_build_dir "${_tip_case_root}/build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/include")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE
  "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_substitution_mode LANGUAGES C)\n"
  "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
  "add_library(proof_headers INTERFACE)\n"
  "target_configure_sources(proof_headers INTERFACE SUBSTITUTION_MODE VARIABLES FILES include/value.h.in)\n")

file(WRITE "${_tip_source_dir}/include/value.h.in" "#define PROOF_VALUE \${PROJECT_NAME}\n")

set(_tip_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_tip_source_dir}"
    -B
    "${_tip_build_dir}"
    ${_tip_toolchain_args})

_tip_proof_run_step(NAME "configure" COMMAND ${_tip_configure_command})
set(_tip_generated_header "${_tip_build_dir}/configured/proof_headers/value.h")
_tip_proof_assert_exists("${_tip_generated_header}")
_tip_proof_assert_file_contains("${_tip_generated_header}" "#define PROOF_VALUE proof_substitution_mode")

message(STATUS "[proof] SUBSTITUTION_MODE VARIABLES proof passed.")
