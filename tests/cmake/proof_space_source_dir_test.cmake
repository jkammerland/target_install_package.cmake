cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/space-source-dir")
set(_tip_source_dir "${_tip_case_root}/source with spaces")
set(_tip_build_dir "${_tip_case_root}/build")
set(_tip_install_prefix "${_tip_case_root}/install")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_space_source_dir VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(space_lib STATIC src/space.cpp)\n"
  "target_compile_features(space_lib PUBLIC cxx_std_17)\n"
  "target_install_package(space_lib)\n")

file(WRITE "${_tip_source_dir}/src/space.cpp" "int proof_space_source_dir_value() { return 1; }\n")

set(_tip_configure_command "${CMAKE_COMMAND}" -S "${_tip_source_dir}" -B "${_tip_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})

_tip_proof_run_step(NAME "configure-space-source-dir" COMMAND ${_tip_configure_command})
_tip_proof_run_step(NAME "build-space-source-dir" COMMAND "${CMAKE_COMMAND}" --build "${_tip_build_dir}" --config Release)
_tip_proof_run_step(NAME "install-space-source-dir" COMMAND "${CMAKE_COMMAND}" --install "${_tip_build_dir}" --config Release --prefix "${_tip_install_prefix}")
_tip_proof_assert_exists("${_tip_install_prefix}/share/cmake/space_lib/space_libConfig.cmake")

message(STATUS "[proof] Space source directory proof passed.")
