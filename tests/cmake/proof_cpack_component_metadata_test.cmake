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

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-component-metadata")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_case_root}/fixture-build")
set(_tip_install_prefix "${_tip_case_root}/fixture-install")
set(_tip_package_dir "${_tip_case_root}/packages")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_cpack_component_metadata VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "export_cpack(PACKAGE_NAME ProofCpackComponents PACKAGE_VERSION 1.0.0 GENERATORS TGZ NO_DEFAULT_GENERATORS)\n"
  "add_library(proof_core SHARED src/core.cpp)\n"
  "set_target_properties(proof_core PROPERTIES VERSION \${PROJECT_VERSION} SOVERSION \${PROJECT_VERSION_MAJOR})\n"
  "target_compile_features(proof_core PUBLIC cxx_std_17)\n"
  "add_library(proof_storage SHARED src/storage.cpp)\n"
  "set_target_properties(proof_storage PROPERTIES VERSION \${PROJECT_VERSION} SOVERSION \${PROJECT_VERSION_MAJOR})\n"
  "target_link_libraries(proof_storage PUBLIC proof_core)\n"
  "target_compile_features(proof_storage PUBLIC cxx_std_17)\n"
  "add_library(proof_sdk STATIC src/sdk.cpp)\n"
  "target_compile_features(proof_sdk PUBLIC cxx_std_17)\n"
  "if(WIN32)\n"
  "  set_target_properties(proof_core proof_storage PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)\n"
  "endif()\n"
  "target_install_package(proof_core EXPORT_NAME proof_cpack_component_pkg NAMESPACE Proof:: COMPONENT Core INCLUDE_ON_FIND_PACKAGE cmake/proof-extra.cmake ADDITIONAL_FILES cmake/proof-doc.txt ADDITIONAL_FILES_COMPONENTS Documentation)\n"
  "target_install_package(proof_storage EXPORT_NAME proof_cpack_component_pkg NAMESPACE Proof:: COMPONENT Storage)\n"
  "target_install_package(proof_sdk EXPORT_NAME proof_cpack_component_pkg NAMESPACE Proof:: COMPONENT SdkOnly)\n")

file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/cmake")
file(WRITE "${_tip_fixture_source_dir}/src/core.cpp" "int proof_core_value() { return 41; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/storage.cpp" "int proof_core_value(); int proof_storage_value() { return proof_core_value() + 1; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/sdk.cpp" "int proof_sdk_value() { return 43; }\n")
file(WRITE "${_tip_fixture_source_dir}/cmake/proof-extra.cmake" "set(proof_cpack_component_pkg_EXTRA_INCLUDED TRUE)\n")
file(WRITE "${_tip_fixture_source_dir}/cmake/proof-doc.txt" "Proof documentation\n")

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

set(_tip_config_file "${_tip_install_prefix}/share/cmake/proof_cpack_component_pkg/proof_cpack_component_pkgConfig.cmake")
set(_tip_extra_file "${_tip_install_prefix}/share/cmake/proof_cpack_component_pkg/proof-extra.cmake")
_tip_proof_assert_exists("${_tip_config_file}")
_tip_proof_assert_exists("${_tip_extra_file}")
_tip_proof_assert_file_contains("${_tip_config_file}" "proof-extra.cmake")

file(GLOB _tip_sdk_libraries "${_tip_install_prefix}/lib*/*proof_sdk*")
if(NOT _tip_sdk_libraries)
  _tip_proof_fail("Expected the unified Development component to install proof_sdk development artifacts")
endif()

set(_tip_cpack_config_file "${_tip_fixture_build_dir}/CPackConfig.cmake")
_tip_proof_assert_exists("${_tip_cpack_config_file}")
file(READ "${_tip_cpack_config_file}" _tip_cpack_config_content)

foreach(_tip_expected_component IN ITEMS Core Storage Development Documentation)
  string(FIND "${_tip_cpack_config_content}" "${_tip_expected_component}" _tip_component_index)
  if(_tip_component_index EQUAL -1)
    _tip_proof_fail("Expected CPackConfig.cmake to contain auto-detected component '${_tip_expected_component}'")
  endif()
endforeach()

foreach(_tip_unexpected_component IN ITEMS SdkOnly Core_Development Storage_Development)
  string(FIND "${_tip_cpack_config_content}" "${_tip_unexpected_component}" _tip_component_index)
  if(NOT _tip_component_index EQUAL -1)
    _tip_proof_fail("Did not expect CPackConfig.cmake to contain legacy split SDK component '${_tip_unexpected_component}'")
  endif()
endforeach()

_tip_proof_assert_file_not_contains("${_tip_cpack_config_file}" "CPACK_COMPONENTS_DEFAULT")
_tip_proof_assert_file_contains("${_tip_cpack_config_file}" "CPACK_COMPONENT_DEVELOPMENT_DISABLED \"TRUE\"")
_tip_proof_assert_file_contains("${_tip_cpack_config_file}" "CPACK_COMPONENT_DOCUMENTATION_DISABLED \"TRUE\"")
_tip_proof_assert_file_not_contains("${_tip_cpack_config_file}" "CPACK_COMPONENT_CORE_DISABLED \"TRUE\"")
_tip_proof_assert_file_not_contains("${_tip_cpack_config_file}" "CPACK_COMPONENT_STORAGE_DISABLED \"TRUE\"")

string(REGEX MATCH "set\\(CPACK_COMPONENT_DEVELOPMENT_DEPENDS \"([^\"]*)\"\\)" _tip_development_dep_match "${_tip_cpack_config_content}")
if(NOT _tip_development_dep_match)
  _tip_proof_fail("Expected Development CPack dependency declaration")
endif()

set(_tip_development_dependencies "${CMAKE_MATCH_1}")
foreach(_tip_expected_dependency IN ITEMS Core Storage)
  if(NOT "${_tip_expected_dependency}" IN_LIST _tip_development_dependencies)
    _tip_proof_fail("Expected Development to depend on '${_tip_expected_dependency}', got: ${_tip_development_dependencies}")
  endif()
endforeach()

foreach(_tip_unexpected_dependency IN ITEMS SdkOnly Development)
  if("${_tip_unexpected_dependency}" IN_LIST _tip_development_dependencies)
    _tip_proof_fail("Did not expect Development to depend on '${_tip_unexpected_dependency}', got: ${_tip_development_dependencies}")
  endif()
endforeach()

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

foreach(_tip_component IN ITEMS Core Storage Development Documentation)
  file(GLOB _tip_${_tip_component}_archives "${_tip_package_dir}/*-${_tip_component}.tar.gz")
  list(LENGTH _tip_${_tip_component}_archives _tip_${_tip_component}_archive_count)
  if(NOT _tip_${_tip_component}_archive_count EQUAL 1)
    _tip_proof_fail("Expected exactly one ${_tip_component} archive, got ${_tip_${_tip_component}_archive_count}: ${_tip_${_tip_component}_archives}")
  endif()
endforeach()

file(GLOB _tip_unexpected_sdk_archives "${_tip_package_dir}/*-SdkOnly.tar.gz")
if(_tip_unexpected_sdk_archives)
  _tip_proof_fail("Static-only target should not generate an empty SdkOnly runtime archive: ${_tip_unexpected_sdk_archives}")
endif()

foreach(_tip_runtime_component IN ITEMS Core Storage)
  list(GET _tip_${_tip_runtime_component}_archives 0 _tip_runtime_archive)
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar tf "${_tip_runtime_archive}"
    RESULT_VARIABLE _tip_tar_result
    OUTPUT_VARIABLE _tip_runtime_archive_contents
    ERROR_VARIABLE _tip_tar_error)
  if(NOT _tip_tar_result EQUAL 0)
    _tip_proof_fail("Failed to list ${_tip_runtime_component} archive: ${_tip_tar_error}")
  endif()
  string(TOLOWER "${_tip_runtime_component}" _tip_runtime_component_lower)
  string(FIND "${_tip_runtime_archive_contents}" "proof_${_tip_runtime_component_lower}" _tip_runtime_payload_index)
  if(_tip_runtime_payload_index EQUAL -1)
    _tip_proof_fail("Expected ${_tip_runtime_component} archive to contain its runtime payload")
  endif()
  foreach(_tip_unexpected_entry IN ITEMS "share/cmake" "proof_sdk" "proof-extra.cmake")
    string(FIND "${_tip_runtime_archive_contents}" "${_tip_unexpected_entry}" _tip_unexpected_entry_index)
    if(NOT _tip_unexpected_entry_index EQUAL -1)
      _tip_proof_fail("Did not expect ${_tip_runtime_component} archive to contain SDK entry '${_tip_unexpected_entry}'")
    endif()
  endforeach()
endforeach()

list(GET _tip_Development_archives 0 _tip_development_archive)
execute_process(
  COMMAND "${CMAKE_COMMAND}" -E tar tf "${_tip_development_archive}"
  RESULT_VARIABLE _tip_tar_result
  OUTPUT_VARIABLE _tip_development_archive_contents
  ERROR_VARIABLE _tip_tar_error)
if(NOT _tip_tar_result EQUAL 0)
  _tip_proof_fail("Failed to list Development archive: ${_tip_tar_error}")
endif()
foreach(_tip_expected_entry IN ITEMS "share/cmake/proof_cpack_component_pkg" "proof-extra.cmake" "proof_sdk")
  string(FIND "${_tip_development_archive_contents}" "${_tip_expected_entry}" _tip_expected_entry_index)
  if(_tip_expected_entry_index EQUAL -1)
    _tip_proof_fail("Expected Development archive to contain '${_tip_expected_entry}'")
  endif()
endforeach()

list(GET _tip_Documentation_archives 0 _tip_documentation_archive)
execute_process(
  COMMAND "${CMAKE_COMMAND}" -E tar tf "${_tip_documentation_archive}"
  RESULT_VARIABLE _tip_tar_result
  OUTPUT_VARIABLE _tip_documentation_archive_contents
  ERROR_VARIABLE _tip_tar_error)
if(NOT _tip_tar_result EQUAL 0)
  _tip_proof_fail("Failed to list Documentation archive: ${_tip_tar_error}")
endif()
string(FIND "${_tip_documentation_archive_contents}" "proof-doc.txt" _tip_doc_entry_index)
if(_tip_doc_entry_index EQUAL -1)
  _tip_proof_fail("Expected Documentation archive to contain proof-doc.txt")
endif()

message(STATUS "[proof] CPack component metadata proof passed.")
