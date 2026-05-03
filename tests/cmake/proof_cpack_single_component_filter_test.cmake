cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()
if(NOT CMAKE_CPACK_COMMAND)
  _tip_proof_fail("CMAKE_CPACK_COMMAND is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-single-component-filter")
set(_tip_source_dir "${_tip_case_root}/fixture-src")
set(_tip_build_dir "${_tip_case_root}/fixture-build")
set(_tip_package_dir "${_tip_case_root}/packages")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_cpack_single_component_filter VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(single_filter SHARED src/single.cpp)\n"
  "set_target_properties(single_filter PROPERTIES VERSION \${PROJECT_VERSION} SOVERSION \${PROJECT_VERSION_MAJOR})\n"
  "if(WIN32)\n"
  "  set_target_properties(single_filter PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)\n"
  "endif()\n"
  "target_install_package(single_filter EXPORT_NAME SingleFilterPkg)\n"
  "export_cpack(PACKAGE_NAME SingleFilter PACKAGE_VERSION 1.0.0 GENERATORS TGZ COMPONENTS Development DEFAULT_COMPONENTS Development NO_DEFAULT_GENERATORS)\n")
file(WRITE "${_tip_source_dir}/src/single.cpp" "int single_filter_value() { return 7; }\n")

set(_tip_configure_command "${CMAKE_COMMAND}" -S "${_tip_source_dir}" -B "${_tip_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "fixture-configure" COMMAND ${_tip_configure_command})
_tip_proof_run_step(
  NAME
  "fixture-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_build_dir}"
  --config
  Release)

set(_tip_cpack_config_file "${_tip_build_dir}/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_cpack_config_file}" "CPACK_COMPONENTS_ALL \"Development\"")
_tip_proof_assert_file_contains("${_tip_cpack_config_file}" "CPACK_ARCHIVE_COMPONENT_INSTALL \"ON\"")
_tip_proof_assert_file_contains("${_tip_cpack_config_file}" "CPACK_COMPONENT_DEVELOPMENT_DISABLED \"FALSE\"")
_tip_proof_assert_file_not_contains("${_tip_cpack_config_file}" "CPACK_COMPONENTS_DEFAULT")
_tip_proof_assert_file_not_contains("${_tip_cpack_config_file}" "CPACK_COMPONENT_DEVELOPMENT_DEPENDS \"Runtime\"")

_tip_proof_run_step(
  NAME
  "fixture-cpack-tgz"
  COMMAND
  "${CMAKE_CPACK_COMMAND}"
  -G
  TGZ
  --config
  "${_tip_cpack_config_file}"
  -B
  "${_tip_package_dir}")

file(GLOB _tip_archives "${_tip_package_dir}/*.tar.gz")
list(LENGTH _tip_archives _tip_archive_count)
if(NOT _tip_archive_count EQUAL 1)
  _tip_proof_fail("Expected exactly one Development archive, got ${_tip_archive_count}: ${_tip_archives}")
endif()
list(GET _tip_archives 0 _tip_archive)

execute_process(
  COMMAND "${CMAKE_COMMAND}" -E tar tf "${_tip_archive}"
  RESULT_VARIABLE _tip_tar_result
  OUTPUT_VARIABLE _tip_archive_contents
  ERROR_VARIABLE _tip_tar_error)
if(NOT _tip_tar_result EQUAL 0)
  _tip_proof_fail("Failed to list Development archive: ${_tip_tar_error}")
endif()

foreach(_tip_expected_entry IN ITEMS "share/cmake/SingleFilterPkg" "SingleFilterPkgConfig.cmake" "single_filter")
  string(FIND "${_tip_archive_contents}" "${_tip_expected_entry}" _tip_expected_entry_index)
  if(_tip_expected_entry_index EQUAL -1)
    _tip_proof_fail("Expected Development archive to contain '${_tip_expected_entry}'")
  endif()
endforeach()

foreach(_tip_runtime_entry IN ITEMS "single_filter.so.1.0.0" "single_filter.so.1" "single_filter.1.0.0.dylib" "single_filter.1.dylib" "single_filter.dll")
  string(FIND "${_tip_archive_contents}" "${_tip_runtime_entry}" _tip_runtime_entry_index)
  if(NOT _tip_runtime_entry_index EQUAL -1)
    _tip_proof_fail("Explicit Development-only package should not contain runtime entry '${_tip_runtime_entry}'")
  endif()
endforeach()

message(STATUS "[proof] CPack single-component filter proof passed.")
