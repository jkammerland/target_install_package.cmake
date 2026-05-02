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
set(_tip_package_dir "${_tip_case_root}/packages")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_package_dir}")

if(NOT CMAKE_CPACK_COMMAND)
  _tip_proof_fail("CMAKE_CPACK_COMMAND is required for additional files package proof")
endif()

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

_tip_proof_run_step(
  NAME
  "package"
  COMMAND
  "${CMAKE_CPACK_COMMAND}"
  -G
  TGZ
  -C
  Release
  --config
  "${_tip_build_dir}/CPackConfig.cmake"
  -B
  "${_tip_package_dir}")

file(GLOB _tip_runtime_archives "${_tip_package_dir}/*Runtime*.tar.gz" "${_tip_package_dir}/*RUNTIME*.tar.gz")
file(GLOB _tip_notices_archives "${_tip_package_dir}/*Notices*.tar.gz" "${_tip_package_dir}/*NOTICES*.tar.gz")
file(GLOB _tip_development_archives "${_tip_package_dir}/*Development*.tar.gz" "${_tip_package_dir}/*DEVELOPMENT*.tar.gz")

list(LENGTH _tip_runtime_archives _tip_runtime_archive_count)
if(NOT _tip_runtime_archive_count EQUAL 1)
  _tip_proof_fail("Expected one runtime archive, found ${_tip_runtime_archive_count}: ${_tip_runtime_archives}")
endif()

list(LENGTH _tip_notices_archives _tip_notices_archive_count)
if(NOT _tip_notices_archive_count EQUAL 1)
  _tip_proof_fail("Expected one notices archive, found ${_tip_notices_archive_count}: ${_tip_notices_archives}")
endif()

list(LENGTH _tip_development_archives _tip_development_archive_count)
if(NOT _tip_development_archive_count EQUAL 1)
  _tip_proof_fail("Expected one development archive, found ${_tip_development_archive_count}: ${_tip_development_archives}")
endif()

list(GET _tip_runtime_archives 0 _tip_runtime_archive)
list(GET _tip_notices_archives 0 _tip_notices_archive)
list(GET _tip_development_archives 0 _tip_development_archive)

foreach(_tip_archive_var runtime notices development)
  set(_tip_archive "${_tip_${_tip_archive_var}_archive}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar tf "${_tip_archive}"
    RESULT_VARIABLE _tip_tar_result
    OUTPUT_VARIABLE _tip_tar_output
    ERROR_VARIABLE _tip_tar_error)
  if(NOT _tip_tar_result EQUAL 0)
    _tip_proof_fail("Failed to list ${_tip_archive}: ${_tip_tar_error}")
  endif()
  set(_tip_${_tip_archive_var}_tar_output "${_tip_tar_output}")
endforeach()

foreach(_tip_archive_var runtime notices)
  set(_tip_tar_output "${_tip_${_tip_archive_var}_tar_output}")
  set(_tip_archive "${_tip_${_tip_archive_var}_archive}")
  string(FIND "${_tip_tar_output}" "share/proof/NOTICE.txt" _tip_notice_index)
  if(_tip_notice_index EQUAL -1)
    _tip_proof_fail("Expected ${_tip_archive} to contain share/proof/NOTICE.txt")
  endif()
endforeach()

string(FIND "${_tip_development_tar_output}" "share/proof/NOTICE.txt" _tip_development_notice_index)
if(NOT _tip_development_notice_index EQUAL -1)
  _tip_proof_fail("Did not expect ${_tip_development_archive} to contain share/proof/NOTICE.txt")
endif()

message(STATUS "[proof] Additional files components proof passed.")
