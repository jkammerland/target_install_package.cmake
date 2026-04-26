cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/component-find-package")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_case_root}/fixture-build")
set(_tip_install_prefix "${_tip_case_root}/fixture-install")
set(_tip_consumer_source_dir "${_tip_case_root}/consumer-src")
set(_tip_consumer_build_dir "${_tip_case_root}/consumer-build")
set(_tip_bad_template_source_dir "${_tip_case_root}/bad-template-src")
set(_tip_bad_template_build_dir "${_tip_case_root}/bad-template-build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_consumer_source_dir}")
file(MAKE_DIRECTORY "${_tip_bad_template_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE
  "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_component_fixture VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_component_lib STATIC src/proof.cpp)\n"
  "target_compile_features(proof_component_lib PUBLIC cxx_std_17)\n"
  "target_install_package(proof_component_lib EXPORT_NAME proof_component_pkg COMPONENT Core VERSION ${PROJECT_VERSION})\n")

file(WRITE "${_tip_fixture_source_dir}/src/proof.cpp" "int proof_component_value() { return 7; }\n")

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

set(_tip_package_dir "${_tip_install_prefix}/share/cmake/proof_component_pkg")
set(_tip_config_file "${_tip_package_dir}/proof_component_pkgConfig.cmake")
_tip_proof_assert_file_contains("${_tip_config_file}" "set(proof_component_pkg_Core_FOUND TRUE)")

file(
  WRITE
  "${_tip_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_component_consumer LANGUAGES CXX)\n"
  "find_package(proof_component_pkg CONFIG REQUIRED COMPONENTS Core PATHS \"${_tip_package_dir}\" NO_DEFAULT_PATH)\n"
  "add_executable(proof_component_consumer main.cpp)\n"
  "target_link_libraries(proof_component_consumer PRIVATE proof_component_pkg::proof_component_lib)\n")
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

file(
  WRITE
  "${_tip_bad_template_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_component_bad_template VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_bad_template_lib STATIC src/proof.cpp)\n"
  "target_install_package(proof_bad_template_lib EXPORT_NAME proof_bad_template_pkg COMPONENT Core CONFIG_TEMPLATE \"\${CMAKE_CURRENT_LIST_DIR}/bad-config.cmake.in\")\n")

file(WRITE "${_tip_bad_template_source_dir}/src/proof.cpp" "int proof_bad_template_value() { return 9; }\n")
file(
  WRITE
  "${_tip_bad_template_source_dir}/bad-config.cmake.in"
  "@PACKAGE_INIT@\n"
  "include(\"\${CMAKE_CURRENT_LIST_DIR}/@ARG_EXPORT_NAME@Targets.cmake\")\n"
  "check_required_components(@ARG_EXPORT_NAME@)\n")

set(_tip_bad_template_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_tip_bad_template_source_dir}"
    -B
    "${_tip_bad_template_build_dir}"
    "-DCMAKE_BUILD_TYPE=Release"
    ${_tip_toolchain_args})

_tip_proof_expect_failure(
  NAME
  "bad-custom-template-configure"
  COMMAND
  ${_tip_bad_template_configure_command}
  EXPECT_CONTAINS
  "@PACKAGE_COMPONENT_DEPENDENCIES_CONTENT@")

message(STATUS "[proof] Component-aware find_package proof passed.")
