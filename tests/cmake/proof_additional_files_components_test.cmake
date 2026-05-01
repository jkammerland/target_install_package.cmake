cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/additional-files-components")
set(_tip_source_dir "${_tip_case_root}/source")
set(_tip_build_dir "${_tip_case_root}/build")
set(_tip_runtime_prefix "${_tip_case_root}/runtime-install")
set(_tip_notices_prefix "${_tip_case_root}/notices-install")
set(_tip_development_prefix "${_tip_case_root}/development-install")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_additional_files_components VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_files_lib STATIC src/proof.cpp)\n"
  "target_compile_features(proof_files_lib PUBLIC cxx_std_17)\n"
  "target_install_package(proof_files_lib ADDITIONAL_FILES NOTICE.txt ADDITIONAL_FILES_DESTINATION share/proof ADDITIONAL_FILES_COMPONENTS Runtime Notices)\n"
  "export_cpack(PACKAGE_NAME ProofAdditionalFiles GENERATORS TGZ)\n")

file(WRITE "${_tip_source_dir}/src/proof.cpp" "int proof_files_value() { return 5; }\n")
file(WRITE "${_tip_source_dir}/NOTICE.txt" "proof notice\n")

set(_tip_configure_command "${CMAKE_COMMAND}" -S "${_tip_source_dir}" -B "${_tip_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})

_tip_proof_run_step(NAME "configure" COMMAND ${_tip_configure_command})
_tip_proof_assert_file_contains("${_tip_build_dir}/CPackConfig.cmake" "CPACK_COMPONENTS_ALL")
_tip_proof_assert_file_contains("${_tip_build_dir}/CPackConfig.cmake" "Notices")
_tip_proof_run_step(
  NAME
  "build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_build_dir}"
  --config
  Release)
_tip_proof_run_step(
  NAME
  "install-runtime"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build_dir}"
  --config
  Release
  --prefix
  "${_tip_runtime_prefix}"
  --component
  Runtime)
_tip_proof_run_step(
  NAME
  "install-notices"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build_dir}"
  --config
  Release
  --prefix
  "${_tip_notices_prefix}"
  --component
  Notices)
_tip_proof_run_step(
  NAME
  "install-development"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build_dir}"
  --config
  Release
  --prefix
  "${_tip_development_prefix}"
  --component
  Development)

_tip_proof_assert_exists("${_tip_runtime_prefix}/share/proof/NOTICE.txt")
_tip_proof_assert_exists("${_tip_notices_prefix}/share/proof/NOTICE.txt")
_tip_proof_assert_not_exists("${_tip_development_prefix}/share/proof/NOTICE.txt")

message(STATUS "[proof] Additional files components proof passed.")
