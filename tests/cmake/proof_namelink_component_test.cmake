cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(WIN32)
  message(STATUS "[proof] Skipping namelink component proof on Windows.")
  return()
endif()

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/namelink-component")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_case_root}/fixture-build")
set(_tip_runtime_install_prefix "${_tip_case_root}/runtime-install")
set(_tip_development_install_prefix "${_tip_case_root}/development-install")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_namelink_component VERSION 1.2.3 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_namelink SHARED src/proof.cpp)\n"
  "set_target_properties(proof_namelink PROPERTIES VERSION \${PROJECT_VERSION} SOVERSION \${PROJECT_VERSION_MAJOR})\n"
  "target_compile_features(proof_namelink PUBLIC cxx_std_17)\n"
  "target_install_package(proof_namelink EXPORT_NAME proof_namelink_pkg COMPONENT Core)\n")

file(WRITE "${_tip_fixture_source_dir}/src/proof.cpp" "int proof_namelink_value() { return 7; }\n")

set(_tip_fixture_configure_command "${CMAKE_COMMAND}" -S "${_tip_fixture_source_dir}" -B "${_tip_fixture_build_dir}" "-DCMAKE_BUILD_TYPE=Release" "-DCMAKE_INSTALL_LIBDIR=lib" ${_tip_toolchain_args})

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
  "fixture-install-runtime"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_fixture_build_dir}"
  --config
  Release
  --prefix
  "${_tip_runtime_install_prefix}"
  --component
  Core)

if(APPLE)
  set(_tip_runtime_library "${_tip_runtime_install_prefix}/lib/libproof_namelink.1.2.3.dylib")
  set(_tip_runtime_soname_link "${_tip_runtime_install_prefix}/lib/libproof_namelink.1.dylib")
  set(_tip_development_namelink "${_tip_runtime_install_prefix}/lib/libproof_namelink.dylib")
  set(_tip_development_namelink_after_dev_install "${_tip_development_install_prefix}/lib/libproof_namelink.dylib")
else()
  set(_tip_runtime_library "${_tip_runtime_install_prefix}/lib/libproof_namelink.so.1.2.3")
  set(_tip_runtime_soname_link "${_tip_runtime_install_prefix}/lib/libproof_namelink.so.1")
  set(_tip_development_namelink "${_tip_runtime_install_prefix}/lib/libproof_namelink.so")
  set(_tip_development_namelink_after_dev_install "${_tip_development_install_prefix}/lib/libproof_namelink.so")
endif()

_tip_proof_assert_exists("${_tip_runtime_library}")
_tip_proof_assert_exists("${_tip_runtime_soname_link}")
_tip_proof_assert_not_exists("${_tip_development_namelink}")

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
  "${_tip_development_install_prefix}"
  --component
  Development)

if(NOT EXISTS "${_tip_development_namelink_after_dev_install}" AND NOT IS_SYMLINK "${_tip_development_namelink_after_dev_install}")
  _tip_proof_fail("Expected development namelink to exist: ${_tip_development_namelink_after_dev_install}")
endif()

message(STATUS "[proof] Namelink component proof passed.")
