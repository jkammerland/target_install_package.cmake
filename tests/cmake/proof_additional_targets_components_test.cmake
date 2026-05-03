cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/additional-target-components")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_case_root}/fixture-build")
set(_tip_install_prefix "${_tip_case_root}/fixture-install")
set(_tip_consumer_source_dir "${_tip_case_root}/consumer-src")
set(_tip_consumer_build_dir "${_tip_case_root}/consumer-build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_consumer_source_dir}")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_additional_targets_components VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_dep STATIC src/dep.cpp)\n"
  "target_compile_features(proof_dep PUBLIC cxx_std_17)\n"
  "add_library(proof_core STATIC src/core.cpp)\n"
  "target_link_libraries(proof_core PUBLIC proof_dep)\n"
  "target_compile_features(proof_core PUBLIC cxx_std_17)\n"
  "target_install_package(proof_core EXPORT_NAME proof_additional_targets_pkg COMPONENT Core ADDITIONAL_TARGETS proof_dep)\n")

file(WRITE "${_tip_fixture_source_dir}/src/dep.cpp" "int proof_dep_value() { return 3; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/core.cpp" "int proof_dep_value(); int proof_core_value() { return proof_dep_value(); }\n")

set(_tip_fixture_configure_command "${CMAKE_COMMAND}" -S "${_tip_fixture_source_dir}" -B "${_tip_fixture_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})

_tip_proof_run_step(NAME "fixture-configure" COMMAND ${_tip_fixture_configure_command})
_tip_proof_run_step(
  NAME
  "fixture-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_fixture_build_dir}"
  --config
  Release)
_tip_proof_run_step(
  NAME
  "fixture-install-development"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_fixture_build_dir}"
  --config
  Release
  --prefix
  "${_tip_install_prefix}"
  --component
  Development)

file(
  WRITE "${_tip_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n" "project(proof_additional_targets_consumer LANGUAGES CXX)\n"
  "find_package(proof_additional_targets_pkg CONFIG REQUIRED PATHS \"${_tip_install_prefix}\" NO_DEFAULT_PATH)\n" "add_executable(proof_additional_targets_consumer main.cpp)\n"
  "target_link_libraries(proof_additional_targets_consumer PRIVATE proof_additional_targets_pkg::proof_core)\n")
file(WRITE "${_tip_consumer_source_dir}/main.cpp" "int proof_core_value(); int main() { return proof_core_value() == 3 ? 0 : 1; }\n")

set(_tip_consumer_configure_command "${CMAKE_COMMAND}" -S "${_tip_consumer_source_dir}" -B "${_tip_consumer_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})

_tip_proof_run_step(NAME "consumer-configure" COMMAND ${_tip_consumer_configure_command})
_tip_proof_run_step(
  NAME
  "consumer-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_consumer_build_dir}"
  --config
  Release)

if(WIN32)
  set(_tip_executable_suffix ".exe")
else()
  set(_tip_executable_suffix "${CMAKE_EXECUTABLE_SUFFIX}")
endif()
set(_tip_consumer_executable_candidates
    "${_tip_consumer_build_dir}/proof_additional_targets_consumer${_tip_executable_suffix}" "${_tip_consumer_build_dir}/Release/proof_additional_targets_consumer${_tip_executable_suffix}"
    "${_tip_consumer_build_dir}/proof_additional_targets_consumer" "${_tip_consumer_build_dir}/Release/proof_additional_targets_consumer")
set(_tip_consumer_executable "")
foreach(_tip_candidate IN LISTS _tip_consumer_executable_candidates)
  if(EXISTS "${_tip_candidate}")
    set(_tip_consumer_executable "${_tip_candidate}")
    break()
  endif()
endforeach()
if(NOT _tip_consumer_executable)
  _tip_proof_fail("Expected consumer executable to exist: ${_tip_consumer_executable_candidates}")
endif()
_tip_proof_run_step(NAME "consumer-run" COMMAND "${_tip_consumer_executable}")

message(STATUS "[proof] Additional target component inheritance proof passed.")
