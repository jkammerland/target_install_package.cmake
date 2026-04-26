cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/versioned-find-package")
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
  WRITE
  "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_versioned_fixture VERSION 1.2.3 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_versioned_lib STATIC src/proof.cpp)\n"
  "target_compile_features(proof_versioned_lib PUBLIC cxx_std_17)\n"
  "target_install_package(proof_versioned_lib EXPORT_NAME proof_versioned_pkg VERSION ${PROJECT_VERSION})\n")

file(WRITE "${_tip_fixture_source_dir}/src/proof.cpp" "int proof_versioned_value() { return 42; }\n")

set(_tip_fixture_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_tip_fixture_source_dir}"
    -B
    "${_tip_fixture_build_dir}"
    "-DCMAKE_BUILD_TYPE=Release"
    ${_tip_toolchain_args})

_tip_proof_run_step(NAME "fixture-configure" COMMAND ${_tip_fixture_configure_command})
_tip_proof_run_step(NAME "fixture-build" COMMAND "${CMAKE_COMMAND}" --build "${_tip_fixture_build_dir}" --config Release)
_tip_proof_run_step(
  NAME
  "fixture-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_fixture_build_dir}"
  --config
  Release
  --prefix
  "${_tip_install_prefix}")

set(_tip_package_dir "${_tip_install_prefix}/share/cmake/proof_versioned_pkg")
set(_tip_expected_version_file "${_tip_package_dir}/proof_versioned_pkgConfigVersion.cmake")
_tip_proof_assert_exists("${_tip_expected_version_file}")

file(
  WRITE
  "${_tip_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_versioned_consumer LANGUAGES CXX)\n"
  "find_package(proof_versioned_pkg 1.2.3 CONFIG REQUIRED PATHS \"${_tip_package_dir}\" NO_DEFAULT_PATH)\n"
  "add_executable(proof_versioned_consumer main.cpp)\n"
  "target_link_libraries(proof_versioned_consumer PRIVATE proof_versioned_pkg::proof_versioned_lib)\n")
file(WRITE "${_tip_consumer_source_dir}/main.cpp" "int main() { return 0; }\n")

set(_tip_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_tip_consumer_source_dir}"
    -B
    "${_tip_consumer_build_dir}"
    "-DCMAKE_BUILD_TYPE=Release"
    ${_tip_toolchain_args})

_tip_proof_run_step(NAME "consumer-configure" COMMAND ${_tip_consumer_configure_command})
_tip_proof_run_step(NAME "consumer-build" COMMAND "${CMAKE_COMMAND}" --build "${_tip_consumer_build_dir}" --config Release)

message(STATUS "[proof] Versioned find_package proof passed.")
