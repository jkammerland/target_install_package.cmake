cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/executable-configure-sources")
set(_tip_source_dir "${_tip_case_root}/source")
set(_tip_build_dir "${_tip_case_root}/build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_source_dir}/include")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_executable_configure_sources VERSION 1.0.0 LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
  "add_executable(proof_configured_app src/main.cpp)\n"
  "target_compile_features(proof_configured_app PRIVATE cxx_std_17)\n"
  "target_configure_sources(proof_configured_app PRIVATE OUTPUT_DIR \"\${CMAKE_CURRENT_BINARY_DIR}/include/proof\" BASE_DIRS \"\${CMAKE_CURRENT_BINARY_DIR}/include\" FILES include/config.hpp.in)\n"
  "add_executable(proof_relative_configured_app src/main_relative.cpp)\n"
  "target_compile_features(proof_relative_configured_app PRIVATE cxx_std_17)\n"
  "target_configure_sources(proof_relative_configured_app PRIVATE OUTPUT_DIR generated/include/proof_rel BASE_DIRS generated/include FILES include/relative_config.hpp.in)\n")

file(WRITE "${_tip_source_dir}/include/config.hpp.in" "#pragma once\n#define PROOF_CONFIGURED_VALUE 42\n")
file(WRITE "${_tip_source_dir}/include/relative_config.hpp.in" "#pragma once\n#define PROOF_RELATIVE_CONFIGURED_VALUE 7\n")
file(WRITE "${_tip_source_dir}/src/main.cpp" "#include <proof/config.hpp>\n" "int main() { return PROOF_CONFIGURED_VALUE == 42 ? 0 : 1; }\n")
file(WRITE "${_tip_source_dir}/src/main_relative.cpp" "#include <proof_rel/relative_config.hpp>\n" "int main() { return PROOF_RELATIVE_CONFIGURED_VALUE == 7 ? 0 : 1; }\n")

set(_tip_configure_command "${CMAKE_COMMAND}" -S "${_tip_source_dir}" -B "${_tip_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})

_tip_proof_run_step(NAME "configure" COMMAND ${_tip_configure_command})
_tip_proof_run_step(
  NAME
  "build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_build_dir}"
  --config
  Release)

message(STATUS "[proof] Executable target_configure_sources proof passed.")
