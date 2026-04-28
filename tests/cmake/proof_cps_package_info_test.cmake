cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()
if(CMAKE_VERSION VERSION_LESS "4.3")
  _tip_proof_fail("proof_cps_package_info requires CMake 4.3 or newer and should not be registered on older CMake versions")
endif()

function(_tip_proof_read_json path out_var)
  _tip_proof_assert_exists("${path}")
  file(READ "${path}" _tip_json_content)
  set(${out_var}
      "${_tip_json_content}"
      PARENT_SCOPE)
endfunction()

function(_tip_proof_assert_json_string path member expected)
  _tip_proof_read_json("${path}" _tip_json_content)
  string(
    JSON
    _tip_json_actual
    ERROR_VARIABLE
    _tip_json_error
    GET
    "${_tip_json_content}"
    "${member}")
  if(_tip_json_error)
    _tip_proof_fail("Expected JSON member '${member}' in '${path}': ${_tip_json_error}")
  endif()
  if(NOT "${_tip_json_actual}" STREQUAL "${expected}")
    _tip_proof_fail("Expected JSON member '${member}' in '${path}' to be '${expected}', got '${_tip_json_actual}'")
  endif()
endfunction()

function(_tip_proof_assert_json_missing path member)
  _tip_proof_read_json("${path}" _tip_json_content)
  string(
    JSON
    _tip_json_actual
    ERROR_VARIABLE
    _tip_json_error
    GET
    "${_tip_json_content}"
    "${member}")
  if(NOT _tip_json_error)
    _tip_proof_fail("Expected JSON member '${member}' to be absent in '${path}', got '${_tip_json_actual}'")
  endif()
endfunction()

function(_tip_proof_assert_json_array path member)
  set(_tip_expected_values ${ARGN})
  _tip_proof_read_json("${path}" _tip_json_content)
  string(JSON _tip_json_length ERROR_VARIABLE _tip_json_error LENGTH "${_tip_json_content}" "${member}")
  if(_tip_json_error)
    _tip_proof_fail("Expected JSON array '${member}' in '${path}': ${_tip_json_error}")
  endif()

  list(LENGTH _tip_expected_values _tip_expected_length)
  if(NOT _tip_json_length EQUAL _tip_expected_length)
    _tip_proof_fail("Expected JSON array '${member}' in '${path}' to have ${_tip_expected_length} entries, got ${_tip_json_length}")
  endif()

  if(_tip_json_length GREATER 0)
    math(EXPR _tip_last_index "${_tip_json_length} - 1")
    foreach(_tip_index RANGE 0 ${_tip_last_index})
      list(GET _tip_expected_values ${_tip_index} _tip_expected_value)
      string(
        JSON
        _tip_json_actual
        ERROR_VARIABLE
        _tip_json_error
        GET
        "${_tip_json_content}"
        "${member}"
        ${_tip_index})
      if(_tip_json_error)
        _tip_proof_fail("Expected JSON array '${member}' index ${_tip_index} in '${path}': ${_tip_json_error}")
      endif()
      if(NOT "${_tip_json_actual}" STREQUAL "${_tip_expected_value}")
        _tip_proof_fail("Expected JSON array '${member}' index ${_tip_index} in '${path}' to be '${_tip_expected_value}', got '${_tip_json_actual}'")
      endif()
    endforeach()
  endif()
endfunction()

function(_tip_proof_assert_json_path_string path expected)
  set(_tip_json_path ${ARGN})
  if(NOT _tip_json_path)
    _tip_proof_fail("_tip_proof_assert_json_path_string requires at least one JSON path element")
  endif()

  _tip_proof_read_json("${path}" _tip_json_content)
  string(
    JSON
    _tip_json_actual
    ERROR_VARIABLE
    _tip_json_error
    GET
    "${_tip_json_content}"
    ${_tip_json_path})
  if(_tip_json_error)
    _tip_proof_fail("Expected JSON path '${_tip_json_path}' in '${path}': ${_tip_json_error}")
  endif()
  if(NOT "${_tip_json_actual}" STREQUAL "${expected}")
    _tip_proof_fail("Expected JSON path '${_tip_json_path}' in '${path}' to be '${expected}', got '${_tip_json_actual}'")
  endif()
endfunction()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cps-package-info")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_case_root}/fixture-build")
set(_tip_install_prefix "${_tip_case_root}/fixture-install")
set(_tip_consumer_source_dir "${_tip_case_root}/consumer-src")
set(_tip_consumer_build_dir "${_tip_case_root}/consumer-build")
set(_tip_consumer_relwithdebinfo_build_dir "${_tip_case_root}/consumer-relwithdebinfo-build")
set(_tip_existing_export_name_source_dir "${_tip_case_root}/existing-export-name-src")
set(_tip_existing_export_name_build_dir "${_tip_case_root}/existing-export-name-build")
set(_tip_existing_export_name_install_prefix "${_tip_case_root}/existing-export-name-install")
set(_tip_existing_export_name_consumer_source_dir "${_tip_case_root}/existing-export-name-consumer-src")
set(_tip_existing_export_name_consumer_build_dir "${_tip_case_root}/existing-export-name-consumer-build")
set(_tip_unsupported_executable_source_dir "${_tip_case_root}/unsupported-executable-src")
set(_tip_unsupported_executable_build_dir "${_tip_case_root}/unsupported-executable-build")
set(_tip_repeat_target_source_dir "${_tip_case_root}/repeat-target-src")
set(_tip_repeat_target_build_dir "${_tip_case_root}/repeat-target-build")
set(_tip_repeat_target_install_prefix "${_tip_case_root}/repeat-target-install")
set(_tip_repeat_target_consumer_source_dir "${_tip_case_root}/repeat-target-consumer-src")
set(_tip_repeat_target_consumer_build_dir "${_tip_case_root}/repeat-target-consumer-build")
set(_tip_repeat_override_source_dir "${_tip_case_root}/repeat-override-src")
set(_tip_repeat_override_build_dir "${_tip_case_root}/repeat-override-build")
set(_tip_repeat_override_install_prefix "${_tip_case_root}/repeat-override-install")
set(_tip_object_default_source_dir "${_tip_case_root}/object-default-src")
set(_tip_object_default_build_dir "${_tip_case_root}/object-default-build")
set(_tip_object_default_install_prefix "${_tip_case_root}/object-default-install")
set(_tip_default_config_source_dir "${_tip_case_root}/default-config-src")
set(_tip_default_config_build_dir "${_tip_case_root}/default-config-build")
set(_tip_default_config_install_prefix "${_tip_case_root}/default-config-install")
set(_tip_default_config_consumer_source_dir "${_tip_case_root}/default-config-consumer-src")
set(_tip_default_config_consumer_build_dir "${_tip_case_root}/default-config-consumer-build")
set(_tip_dependency_source_dir "${_tip_case_root}/dependency-src")
set(_tip_dependency_build_dir "${_tip_case_root}/dependency-build")
set(_tip_dependency_install_prefix "${_tip_case_root}/dependency-install")
set(_tip_dependency_consumer_source_dir "${_tip_case_root}/dependency-consumer-src")
set(_tip_dependency_consumer_build_dir "${_tip_case_root}/dependency-consumer-build")
set(_tip_modules_source_dir "${_tip_case_root}/modules-src")
set(_tip_modules_build_dir "${_tip_case_root}/modules-build")
set(_tip_modules_install_prefix "${_tip_case_root}/modules-install")
set(_tip_project_inherit_source_dir "${_tip_case_root}/project-inherit-src")
set(_tip_project_inherit_build_dir "${_tip_case_root}/project-inherit-build")
set(_tip_project_inherit_install_prefix "${_tip_case_root}/project-inherit-install")
set(_tip_appendix_version_source_dir "${_tip_case_root}/appendix-version-src")
set(_tip_appendix_version_build_dir "${_tip_case_root}/appendix-version-build")
set(_tip_appendix_version_install_prefix "${_tip_case_root}/appendix-version-install")
set(_tip_bad_appendix_source_dir "${_tip_case_root}/bad-appendix-src")
set(_tip_bad_appendix_build_dir "${_tip_case_root}/bad-appendix-build")
set(_tip_bad_appendix_metadata_source_dir "${_tip_case_root}/bad-appendix-metadata-src")
set(_tip_bad_appendix_metadata_build_dir "${_tip_case_root}/bad-appendix-metadata-build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/include/proof_cps")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_consumer_source_dir}")
file(MAKE_DIRECTORY "${_tip_existing_export_name_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_existing_export_name_consumer_source_dir}")
file(MAKE_DIRECTORY "${_tip_unsupported_executable_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_repeat_target_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_repeat_target_consumer_source_dir}")
file(MAKE_DIRECTORY "${_tip_repeat_override_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_object_default_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_default_config_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_default_config_consumer_source_dir}")
file(MAKE_DIRECTORY "${_tip_dependency_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_dependency_consumer_source_dir}")
file(MAKE_DIRECTORY "${_tip_modules_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_project_inherit_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_appendix_version_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_bad_appendix_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_bad_appendix_metadata_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

set(_tip_multi_config_toolchain_args -G "Ninja Multi-Config")
if(DEFINED TIP_CMAKE_MAKE_PROGRAM
   AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL ""
   AND DEFINED TIP_CMAKE_GENERATOR
   AND TIP_CMAKE_GENERATOR MATCHES "^Ninja")
  list(APPEND _tip_multi_config_toolchain_args "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _tip_multi_config_toolchain_args "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _tip_multi_config_toolchain_args "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _tip_multi_config_toolchain_args "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()

execute_process(
  COMMAND "${CMAKE_COMMAND}" -E capabilities
  OUTPUT_VARIABLE _tip_cmake_capabilities
  ERROR_QUIET)
string(FIND "${_tip_cmake_capabilities}" "\"name\":\"Ninja Multi-Config\"" _tip_ninja_multi_config_index)
if(_tip_ninja_multi_config_index EQUAL -1)
  set(_tip_has_ninja_multi_config FALSE)
else()
  set(_tip_has_ninja_multi_config TRUE)
endif()

file(
  WRITE "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_cps_fixture VERSION 2.3.4 DESCRIPTION \"Proof CPS package\" HOMEPAGE_URL \"https://example.invalid/proof-cps\" LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(cps_static STATIC src/static.cpp)\n"
  "target_compile_features(cps_static PUBLIC cxx_std_17)\n"
  "set_target_properties(cps_static PROPERTIES SPDX_LICENSE \"Apache-2.0\")\n"
  "target_sources(cps_static PUBLIC FILE_SET HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"include/proof_cps/static.hpp\")\n"
  "target_compile_definitions(cps_static PUBLIC CPS_STATIC_FLAG=1)\n"
  "target_install_package(cps_static EXPORT_NAME proof_cps_pkg NAMESPACE LegacyCps:: ALIAS_NAME core VERSION \${PROJECT_VERSION} CPS CPS_PACKAGE_NAME ProofCps CPS_VERSION \${PROJECT_VERSION} CPS_COMPAT_VERSION 2.0.0 CPS_VERSION_SCHEMA simple CPS_LICENSE \"MIT\" CPS_DEFAULT_LICENSE \"MIT\" CPS_DESCRIPTION \"Proof CPS package\" CPS_HOMEPAGE_URL \"https://example.invalid/proof-cps\" CPS_DESTINATION \"share/cps/proofcps\" CPS_DEFAULT_TARGETS core iface CPS_DEFAULT_CONFIGURATIONS Release CPS_LOWER_CASE_FILE)\n"
  "add_library(cps_shared SHARED src/shared.cpp)\n"
  "target_compile_features(cps_shared PUBLIC cxx_std_17)\n"
  "target_sources(cps_shared PUBLIC FILE_SET HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"include/proof_cps/shared.hpp\")\n"
  "if(WIN32)\n"
  "  set_target_properties(cps_shared PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)\n"
  "endif()\n"
  "target_install_package(cps_shared EXPORT_NAME proof_cps_pkg NAMESPACE LegacyCps:: ALIAS_NAME shared VERSION \${PROJECT_VERSION})\n"
  "add_library(cps_iface INTERFACE)\n"
  "target_compile_definitions(cps_iface INTERFACE CPS_IFACE_FLAG=1)\n"
  "target_sources(cps_iface INTERFACE FILE_SET HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"include/proof_cps/iface.hpp\")\n"
  "target_install_package(cps_iface EXPORT_NAME proof_cps_pkg NAMESPACE LegacyCps:: ALIAS_NAME iface VERSION \${PROJECT_VERSION})\n")

file(WRITE "${_tip_fixture_source_dir}/include/proof_cps/static.hpp" "int cps_static_value();\n")
file(WRITE "${_tip_fixture_source_dir}/include/proof_cps/shared.hpp" "int cps_shared_value();\n")
file(WRITE "${_tip_fixture_source_dir}/include/proof_cps/iface.hpp" "#pragma once\n")
file(WRITE "${_tip_fixture_source_dir}/src/static.cpp" "#include <proof_cps/static.hpp>\nint cps_static_value() { return 3; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/shared.cpp" "#include <proof_cps/shared.hpp>\nint cps_shared_value() { return 4; }\n")

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
  "fixture-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_fixture_build_dir}"
  --config
  Release
  --prefix
  "${_tip_install_prefix}")

set(_tip_cps_file "${_tip_install_prefix}/share/cps/proofcps/proofcps.cps")
get_filename_component(_tip_cps_dir "${_tip_cps_file}" DIRECTORY)
set(_tip_cps_config_file "${_tip_cps_dir}/proofcps@release.cps")
_tip_proof_assert_exists("${_tip_cps_config_file}")
_tip_proof_assert_json_string("${_tip_cps_file}" "name" "ProofCps")
_tip_proof_assert_json_string("${_tip_cps_file}" "version" "2.3.4")
_tip_proof_assert_json_string("${_tip_cps_file}" "compat_version" "2.0.0")
_tip_proof_assert_json_string("${_tip_cps_file}" "version_schema" "simple")
_tip_proof_assert_json_string("${_tip_cps_file}" "license" "MIT")
_tip_proof_assert_json_string("${_tip_cps_file}" "default_license" "MIT")
_tip_proof_assert_json_string("${_tip_cps_file}" "description" "Proof CPS package")
_tip_proof_assert_json_string("${_tip_cps_file}" "website" "https://example.invalid/proof-cps")
_tip_proof_assert_json_path_string("${_tip_cps_file}" "Apache-2.0" components core license)
_tip_proof_assert_json_array("${_tip_cps_file}" "default_components" core iface)
_tip_proof_assert_json_array("${_tip_cps_file}" "configurations" Release)

file(
  WRITE "${_tip_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.3)\n"
  "project(proof_cps_consumer LANGUAGES CXX)\n"
  "find_package(ProofCps 2.1 CONFIG REQUIRED PATHS \"${_tip_install_prefix}\" NO_DEFAULT_PATH)\n"
  "if(NOT ProofCps_CONFIG MATCHES \"/cps/\")\n"
  "  message(FATAL_ERROR \"Expected CPS package file, got: \${ProofCps_CONFIG}\")\n"
  "endif()\n"
  "foreach(_expected IN ITEMS ProofCps::core ProofCps::shared ProofCps::iface)\n"
  "  if(NOT TARGET \"\${_expected}\")\n"
  "    message(FATAL_ERROR \"Missing CPS imported target: \${_expected}\")\n"
  "  endif()\n"
  "endforeach()\n"
  "if(TARGET LegacyCps::core)\n"
  "  message(FATAL_ERROR \"CPS import unexpectedly used the legacy CMake namespace\")\n"
  "endif()\n"
  "get_target_property(_tip_core_defs ProofCps::core INTERFACE_COMPILE_DEFINITIONS)\n"
  "if(NOT \"CPS_STATIC_FLAG=1\" IN_LIST _tip_core_defs)\n"
  "  message(FATAL_ERROR \"CPS static target definitions were not imported: \${_tip_core_defs}\")\n"
  "endif()\n"
  "get_target_property(_tip_iface_defs ProofCps::iface INTERFACE_COMPILE_DEFINITIONS)\n"
  "if(NOT \"CPS_IFACE_FLAG=1\" IN_LIST _tip_iface_defs)\n"
  "  message(FATAL_ERROR \"CPS interface definitions were not imported: \${_tip_iface_defs}\")\n"
  "endif()\n"
  "if(NOT TARGET ProofCps)\n"
  "  message(FATAL_ERROR \"Missing CPS package default target\")\n"
  "endif()\n"
  "get_target_property(_tip_package_deps ProofCps INTERFACE_LINK_LIBRARIES)\n"
  "if(NOT \"ProofCps::core\" IN_LIST _tip_package_deps OR NOT \"ProofCps::iface\" IN_LIST _tip_package_deps)\n"
  "  message(FATAL_ERROR \"CPS package default target did not include expected defaults: \${_tip_package_deps}\")\n"
  "endif()\n"
  "add_executable(proof_cps_consumer main.cpp)\n"
  "target_link_libraries(proof_cps_consumer PRIVATE ProofCps::core ProofCps::shared ProofCps::iface)\n"
  "add_executable(proof_cps_default_consumer default.cpp)\n"
  "target_link_libraries(proof_cps_default_consumer PRIVATE ProofCps)\n"
  "enable_testing()\n"
  "add_test(NAME proof_cps_consumer_runs COMMAND proof_cps_consumer)\n"
  "add_test(NAME proof_cps_default_consumer_runs COMMAND proof_cps_default_consumer)\n"
  "if(WIN32)\n"
  "  set_tests_properties(proof_cps_consumer_runs proof_cps_default_consumer_runs PROPERTIES ENVIRONMENT_MODIFICATION \"PATH=path_list_prepend:${_tip_install_prefix}/bin\")\n"
  "endif()\n")
file(
  WRITE "${_tip_consumer_source_dir}/main.cpp"
  "#include <proof_cps/static.hpp>\n"
  "#include <proof_cps/shared.hpp>\n"
  "#include <proof_cps/iface.hpp>\n"
  "#ifndef CPS_STATIC_FLAG\n"
  "#error CPS_STATIC_FLAG was not imported\n"
  "#endif\n"
  "#ifndef CPS_IFACE_FLAG\n"
  "#error CPS_IFACE_FLAG was not imported\n"
  "#endif\n"
  "int main() { return (cps_static_value() + cps_shared_value()) == 7 ? 0 : 1; }\n")
file(
  WRITE "${_tip_consumer_source_dir}/default.cpp"
  "#include <proof_cps/static.hpp>\n"
  "#include <proof_cps/iface.hpp>\n"
  "#ifndef CPS_STATIC_FLAG\n"
  "#error CPS_STATIC_FLAG was not imported through package default target\n"
  "#endif\n"
  "#ifndef CPS_IFACE_FLAG\n"
  "#error CPS_IFACE_FLAG was not imported through package default target\n"
  "#endif\n"
  "int main() { return cps_static_value() == 3 ? 0 : 1; }\n")

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
_tip_proof_run_step(
  NAME
  "consumer-test"
  COMMAND
  "${CMAKE_CTEST_COMMAND}"
  --test-dir
  "${_tip_consumer_build_dir}"
  -C
  Release
  --output-on-failure)

set(_tip_consumer_relwithdebinfo_configure_command "${CMAKE_COMMAND}" -S "${_tip_consumer_source_dir}" -B "${_tip_consumer_relwithdebinfo_build_dir}" "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
                                                   ${_tip_toolchain_args})
_tip_proof_run_step(NAME "consumer-relwithdebinfo-configure" COMMAND ${_tip_consumer_relwithdebinfo_configure_command})
_tip_proof_run_step(
  NAME
  "consumer-relwithdebinfo-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_consumer_relwithdebinfo_build_dir}"
  --config
  RelWithDebInfo)
_tip_proof_run_step(
  NAME
  "consumer-relwithdebinfo-test"
  COMMAND
  "${CMAKE_CTEST_COMMAND}"
  --test-dir
  "${_tip_consumer_relwithdebinfo_build_dir}"
  -C
  RelWithDebInfo
  --output-on-failure)

file(
  WRITE "${_tip_existing_export_name_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_cps_existing_export_name VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(cps_internal STATIC src/existing.cpp)\n"
  "set_target_properties(cps_internal PROPERTIES EXPORT_NAME public_component)\n"
  "target_install_package(cps_internal EXPORT_NAME ExistingExportName CPS CPS_PACKAGE_NAME ExistingExportName CPS_DESTINATION \"share/cps/existingexportname\" CPS_LOWER_CASE_FILE)\n")
file(WRITE "${_tip_existing_export_name_source_dir}/src/existing.cpp" "int existing_export_name_value() { return 5; }\n")

set(_tip_existing_export_name_configure_command "${CMAKE_COMMAND}" -S "${_tip_existing_export_name_source_dir}" -B "${_tip_existing_export_name_build_dir}" "-DCMAKE_BUILD_TYPE=Release"
                                                ${_tip_toolchain_args})

_tip_proof_run_step(NAME "existing-export-name-configure" COMMAND ${_tip_existing_export_name_configure_command})
_tip_proof_run_step(
  NAME
  "existing-export-name-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_existing_export_name_build_dir}"
  --config
  Release)
_tip_proof_run_step(
  NAME
  "existing-export-name-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_existing_export_name_build_dir}"
  --config
  Release
  --prefix
  "${_tip_existing_export_name_install_prefix}")

set(_tip_existing_export_name_cps_file "${_tip_existing_export_name_install_prefix}/share/cps/existingexportname/existingexportname.cps")
_tip_proof_assert_json_array("${_tip_existing_export_name_cps_file}" "default_components" public_component)
_tip_proof_assert_file_not_contains("${_tip_existing_export_name_cps_file}" "\"cps_internal\"")

file(
  WRITE "${_tip_existing_export_name_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.3)\n"
  "project(proof_cps_existing_export_name_consumer LANGUAGES CXX)\n"
  "find_package(ExistingExportName CONFIG REQUIRED PATHS \"${_tip_existing_export_name_install_prefix}\" NO_DEFAULT_PATH)\n"
  "if(NOT TARGET ExistingExportName::public_component)\n"
  "  message(FATAL_ERROR \"Missing CPS target for existing EXPORT_NAME\")\n"
  "endif()\n"
  "if(TARGET ExistingExportName::cps_internal)\n"
  "  message(FATAL_ERROR \"CPS target used the build target name instead of EXPORT_NAME\")\n"
  "endif()\n"
  "if(NOT TARGET ExistingExportName)\n"
  "  message(FATAL_ERROR \"Missing CPS package default target\")\n"
  "endif()\n"
  "get_target_property(_tip_default_deps ExistingExportName INTERFACE_LINK_LIBRARIES)\n"
  "if(NOT \"ExistingExportName::public_component\" IN_LIST _tip_default_deps)\n"
  "  message(FATAL_ERROR \"CPS default target did not use existing EXPORT_NAME: \${_tip_default_deps}\")\n"
  "endif()\n"
  "add_executable(existing_export_name_consumer main.cpp)\n"
  "target_link_libraries(existing_export_name_consumer PRIVATE ExistingExportName::public_component)\n"
  "add_executable(existing_export_name_default_consumer main.cpp)\n"
  "target_link_libraries(existing_export_name_default_consumer PRIVATE ExistingExportName)\n"
  "enable_testing()\n"
  "add_test(NAME existing_export_name_consumer_runs COMMAND existing_export_name_consumer)\n"
  "add_test(NAME existing_export_name_default_consumer_runs COMMAND existing_export_name_default_consumer)\n")
file(WRITE "${_tip_existing_export_name_consumer_source_dir}/main.cpp" "extern int existing_export_name_value();\nint main() { return existing_export_name_value() == 5 ? 0 : 1; }\n")
set(_tip_existing_export_name_consumer_configure_command "${CMAKE_COMMAND}" -S "${_tip_existing_export_name_consumer_source_dir}" -B "${_tip_existing_export_name_consumer_build_dir}"
                                                         "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "existing-export-name-consumer-configure" COMMAND ${_tip_existing_export_name_consumer_configure_command})
_tip_proof_run_step(
  NAME
  "existing-export-name-consumer-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_existing_export_name_consumer_build_dir}"
  --config
  Release)
_tip_proof_run_step(
  NAME
  "existing-export-name-consumer-test"
  COMMAND
  "${CMAKE_CTEST_COMMAND}"
  --test-dir
  "${_tip_existing_export_name_consumer_build_dir}"
  -C
  Release
  --output-on-failure)

file(
  WRITE "${_tip_unsupported_executable_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n" "project(proof_cps_unsupported_executable VERSION 1.0.0 LANGUAGES CXX)\n" "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n" "add_executable(cps_tool src/tool.cpp)\n"
  "target_install_package(cps_tool EXPORT_NAME ToolPkg CPS CPS_PACKAGE_NAME ToolPkg CPS_DESTINATION \"share/cps/toolpkg\" CPS_LOWER_CASE_FILE)\n")
file(WRITE "${_tip_unsupported_executable_source_dir}/src/tool.cpp" "int main() { return 0; }\n")
set(_tip_unsupported_executable_configure_command "${CMAKE_COMMAND}" -S "${_tip_unsupported_executable_source_dir}" -B "${_tip_unsupported_executable_build_dir}" "-DCMAKE_BUILD_TYPE=Release"
                                                  ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "unsupported-executable-configure" COMMAND ${_tip_unsupported_executable_configure_command} EXPECT_CONTAINS "does not support target 'cps_tool' of type 'EXECUTABLE'")

file(
  WRITE "${_tip_repeat_target_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_cps_repeat_target VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(repeat_core INTERFACE)\n"
  "set_target_properties(repeat_core PROPERTIES EXPORT_NAME core_export)\n"
  "target_install_package(repeat_core EXPORT_NAME RepeatPkg COMPONENT Sdk ALIAS_NAME api CPS CPS_PACKAGE_NAME RepeatPkg CPS_DESTINATION \"share/cps/repeatpkg\" CPS_LOWER_CASE_FILE)\n"
  "target_install_package(repeat_core EXPORT_NAME RepeatPkg CPS CPS_DEFAULT_TARGETS api CPS_CONFIGURATIONS Release)\n")
set(_tip_repeat_target_configure_command "${CMAKE_COMMAND}" -S "${_tip_repeat_target_source_dir}" -B "${_tip_repeat_target_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "repeat-target-configure" COMMAND ${_tip_repeat_target_configure_command})
_tip_proof_run_step(
  NAME
  "repeat-target-install-component"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_repeat_target_build_dir}"
  --config
  Release
  --prefix
  "${_tip_repeat_target_install_prefix}"
  --component
  Sdk_Development)
set(_tip_repeat_target_cps_file "${_tip_repeat_target_install_prefix}/share/cps/repeatpkg/repeatpkg.cps")
_tip_proof_assert_json_array("${_tip_repeat_target_cps_file}" "default_components" api)
_tip_proof_assert_file_not_contains("${_tip_repeat_target_cps_file}" "\"core\"")
file(
  WRITE "${_tip_repeat_target_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.3)\n"
  "project(proof_cps_repeat_target_consumer LANGUAGES CXX)\n"
  "find_package(RepeatPkg CONFIG REQUIRED PATHS \"${_tip_repeat_target_install_prefix}\" NO_DEFAULT_PATH)\n"
  "if(NOT TARGET RepeatPkg::api)\n"
  "  message(FATAL_ERROR \"Missing preserved alias target\")\n"
  "endif()\n"
  "if(TARGET RepeatPkg::repeat_core)\n"
  "  message(FATAL_ERROR \"Repeated target call reset alias to build target name\")\n"
  "endif()\n"
  "get_target_property(_tip_repeat_deps RepeatPkg INTERFACE_LINK_LIBRARIES)\n"
  "if(NOT \"RepeatPkg::api\" IN_LIST _tip_repeat_deps)\n"
  "  message(FATAL_ERROR \"Repeated target call did not preserve default target: \${_tip_repeat_deps}\")\n"
  "endif()\n")
set(_tip_repeat_target_consumer_configure_command "${CMAKE_COMMAND}" -S "${_tip_repeat_target_consumer_source_dir}" -B "${_tip_repeat_target_consumer_build_dir}" "-DCMAKE_BUILD_TYPE=Release"
                                                  ${_tip_toolchain_args})
_tip_proof_run_step(NAME "repeat-target-consumer-configure" COMMAND ${_tip_repeat_target_consumer_configure_command})

file(
  WRITE "${_tip_repeat_override_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_cps_repeat_override VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(repeat_override INTERFACE)\n"
  "target_install_package(repeat_override EXPORT_NAME RepeatOverride CPS CPS_PACKAGE_NAME RepeatOverride CPS_DESTINATION \"share/cps/repeatoverride\" CPS_LOWER_CASE_FILE)\n"
  "target_install_package(repeat_override EXPORT_NAME RepeatOverride COMPONENT Sdk ALIAS_NAME api CPS CPS_DEFAULT_TARGETS api)\n")
set(_tip_repeat_override_configure_command "${CMAKE_COMMAND}" -S "${_tip_repeat_override_source_dir}" -B "${_tip_repeat_override_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "repeat-override-configure" COMMAND ${_tip_repeat_override_configure_command})
_tip_proof_run_step(
  NAME
  "repeat-override-install-component"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_repeat_override_build_dir}"
  --config
  Release
  --prefix
  "${_tip_repeat_override_install_prefix}"
  --component
  Sdk_Development)
set(_tip_repeat_override_cps_file "${_tip_repeat_override_install_prefix}/share/cps/repeatoverride/repeatoverride.cps")
_tip_proof_assert_json_array("${_tip_repeat_override_cps_file}" "default_components" api)
_tip_proof_assert_file_not_contains("${_tip_repeat_override_cps_file}" "\"repeat_override\"")

file(
  WRITE "${_tip_object_default_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n" "project(proof_cps_object_default VERSION 1.0.0 LANGUAGES CXX)\n" "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n" "add_library(cps_objects OBJECT src/object.cpp)\n"
  "target_install_package(cps_objects EXPORT_NAME ObjectDefault CPS CPS_PACKAGE_NAME ObjectDefault CPS_DESTINATION \"share/cps/objectdefault\" CPS_LOWER_CASE_FILE)\n")
file(WRITE "${_tip_object_default_source_dir}/src/object.cpp" "int cps_object_value() { return 13; }\n")
set(_tip_object_default_configure_command "${CMAKE_COMMAND}" -S "${_tip_object_default_source_dir}" -B "${_tip_object_default_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "object-default-configure" COMMAND ${_tip_object_default_configure_command})
_tip_proof_run_step(
  NAME
  "object-default-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_object_default_build_dir}"
  --config
  Release)
_tip_proof_run_step(
  NAME
  "object-default-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_object_default_build_dir}"
  --config
  Release
  --prefix
  "${_tip_object_default_install_prefix}")
set(_tip_object_default_cps_file "${_tip_object_default_install_prefix}/share/cps/objectdefault/objectdefault.cps")
_tip_proof_assert_json_missing("${_tip_object_default_cps_file}" "default_components")

if(_tip_has_ninja_multi_config)
  file(
    WRITE "${_tip_default_config_source_dir}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 3.25)\n"
    "project(proof_cps_default_config VERSION 1.0.0 LANGUAGES CXX)\n"
    "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
    "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
    "add_library(default_config STATIC src/default_config.cpp)\n"
    "target_compile_definitions(default_config PRIVATE $<$<CONFIG:Release>:TIP_CPS_DEFAULT_RELEASE> $<$<CONFIG:Debug>:TIP_CPS_DEFAULT_DEBUG>)\n"
    "target_install_package(default_config EXPORT_NAME DefaultConfig ALIAS_NAME component CPS CPS_PACKAGE_NAME DefaultConfig CPS_DESTINATION \"share/cps/defaultconfig\" CPS_LOWER_CASE_FILE CPS_DEFAULT_TARGETS component CPS_DEFAULT_CONFIGURATIONS Release CPS_CONFIGURATIONS Debug Release)\n"
  )
  file(WRITE "${_tip_default_config_source_dir}/src/default_config.cpp" "#ifdef TIP_CPS_DEFAULT_RELEASE\n" "int default_config_value() { return 0; }\n" "#else\n"
                                                                        "int default_config_value() { return 1; }\n" "#endif\n")
  set(_tip_default_config_configure_command "${CMAKE_COMMAND}" -S "${_tip_default_config_source_dir}" -B "${_tip_default_config_build_dir}" ${_tip_multi_config_toolchain_args})
  _tip_proof_run_step(NAME "default-config-configure" COMMAND ${_tip_default_config_configure_command})
  _tip_proof_run_step(
    NAME
    "default-config-build-release"
    COMMAND
    "${CMAKE_COMMAND}"
    --build
    "${_tip_default_config_build_dir}"
    --config
    Release)
  _tip_proof_run_step(
    NAME
    "default-config-build-debug"
    COMMAND
    "${CMAKE_COMMAND}"
    --build
    "${_tip_default_config_build_dir}"
    --config
    Debug)
  _tip_proof_run_step(
    NAME
    "default-config-install-release"
    COMMAND
    "${CMAKE_COMMAND}"
    --install
    "${_tip_default_config_build_dir}"
    --config
    Release
    --prefix
    "${_tip_default_config_install_prefix}")
  _tip_proof_run_step(
    NAME
    "default-config-install-debug"
    COMMAND
    "${CMAKE_COMMAND}"
    --install
    "${_tip_default_config_build_dir}"
    --config
    Debug
    --prefix
    "${_tip_default_config_install_prefix}")
  set(_tip_default_config_cps_file "${_tip_default_config_install_prefix}/share/cps/defaultconfig/defaultconfig.cps")
  _tip_proof_assert_json_array("${_tip_default_config_cps_file}" "configurations" Release)

  file(
    WRITE "${_tip_default_config_consumer_source_dir}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 4.3)\n"
    "project(proof_cps_default_config_consumer LANGUAGES CXX)\n"
    "find_package(DefaultConfig CONFIG REQUIRED PATHS \"${_tip_default_config_install_prefix}\" NO_DEFAULT_PATH)\n"
    "add_executable(default_config_consumer main.cpp)\n"
    "target_link_libraries(default_config_consumer PRIVATE DefaultConfig)\n"
    "enable_testing()\n"
    "add_test(NAME default_config_consumer_runs COMMAND default_config_consumer)\n")
  file(WRITE "${_tip_default_config_consumer_source_dir}/main.cpp" "extern int default_config_value();\n" "int main() { return default_config_value(); }\n")
  set(_tip_default_config_consumer_configure_command "${CMAKE_COMMAND}" -S "${_tip_default_config_consumer_source_dir}" -B "${_tip_default_config_consumer_build_dir}"
                                                     "-DCMAKE_BUILD_TYPE=RelWithDebInfo" ${_tip_toolchain_args})
  _tip_proof_run_step(NAME "default-config-consumer-configure" COMMAND ${_tip_default_config_consumer_configure_command})
  _tip_proof_run_step(
    NAME
    "default-config-consumer-build"
    COMMAND
    "${CMAKE_COMMAND}"
    --build
    "${_tip_default_config_consumer_build_dir}"
    --config
    RelWithDebInfo)
  _tip_proof_run_step(
    NAME
    "default-config-consumer-test"
    COMMAND
    "${CMAKE_CTEST_COMMAND}"
    --test-dir
    "${_tip_default_config_consumer_build_dir}"
    -C
    RelWithDebInfo
    --output-on-failure)
else()
  message(STATUS "[proof] Skipping multi-configuration CPS default configuration proof because Ninja Multi-Config is unavailable.")
endif()

file(
  WRITE "${_tip_dependency_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_cps_dependency VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(cps_dep INTERFACE)\n"
  "set_target_properties(cps_dep PROPERTIES EXPORT_FIND_PACKAGE_NAME CpsDepPkg)\n"
  "target_compile_definitions(cps_dep INTERFACE TIP_CPS_DEP_FLAG=1)\n"
  "target_install_package(cps_dep EXPORT_NAME CpsDepPkg ALIAS_NAME dep CPS CPS_PACKAGE_NAME CpsDepPkg CPS_DESTINATION \"share/cps/cpsdeppkg\" CPS_DEFAULT_TARGETS dep CPS_LOWER_CASE_FILE)\n"
  "add_library(cps_requires INTERFACE)\n"
  "target_link_libraries(cps_requires INTERFACE cps_dep)\n"
  "target_install_package(cps_requires EXPORT_NAME CpsRequires ALIAS_NAME consumer CPS CPS_PACKAGE_NAME CpsRequires CPS_DESTINATION \"share/cps/cpsrequires\" CPS_DEFAULT_TARGETS consumer CPS_LOWER_CASE_FILE)\n"
)
set(_tip_dependency_configure_command "${CMAKE_COMMAND}" -S "${_tip_dependency_source_dir}" -B "${_tip_dependency_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "dependency-configure" COMMAND ${_tip_dependency_configure_command})
_tip_proof_run_step(
  NAME
  "dependency-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_dependency_build_dir}"
  --config
  Release
  --prefix
  "${_tip_dependency_install_prefix}")
set(_tip_dependency_cps_file "${_tip_dependency_install_prefix}/share/cps/cpsrequires/cpsrequires.cps")
_tip_proof_assert_json_path_string("${_tip_dependency_cps_file}" "dep" requires CpsDepPkg components 0)
_tip_proof_assert_json_path_string("${_tip_dependency_cps_file}" "CpsDepPkg:dep" components consumer requires 0)

file(
  WRITE "${_tip_dependency_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.3)\n"
  "project(proof_cps_dependency_consumer LANGUAGES CXX)\n"
  "list(PREPEND CMAKE_PREFIX_PATH \"${_tip_dependency_install_prefix}\")\n"
  "find_package(CpsRequires CONFIG REQUIRED)\n"
  "if(NOT CpsRequires_CONFIG MATCHES \"/cps/\")\n"
  "  message(FATAL_ERROR \"Expected CPS package file for CpsRequires, got: \${CpsRequires_CONFIG}\")\n"
  "endif()\n"
  "if(NOT CpsDepPkg_CONFIG MATCHES \"/cps/\")\n"
  "  message(FATAL_ERROR \"Expected nested CPS dependency package file for CpsDepPkg, got: \${CpsDepPkg_CONFIG}\")\n"
  "endif()\n"
  "if(NOT TARGET CpsDepPkg::dep)\n"
  "  message(FATAL_ERROR \"CPS transitive dependency target was not imported\")\n"
  "endif()\n"
  "add_executable(cps_dependency_consumer main.cpp)\n"
  "target_link_libraries(cps_dependency_consumer PRIVATE CpsRequires)\n")
file(WRITE "${_tip_dependency_consumer_source_dir}/main.cpp" "#ifndef TIP_CPS_DEP_FLAG\n" "#error CPS transitive dependency usage requirements were not imported\n" "#endif\n"
                                                             "int main() { return 0; }\n")
set(_tip_dependency_consumer_configure_command "${CMAKE_COMMAND}" -S "${_tip_dependency_consumer_source_dir}" -B "${_tip_dependency_consumer_build_dir}" "-DCMAKE_BUILD_TYPE=Release"
                                               ${_tip_toolchain_args})
_tip_proof_run_step(NAME "dependency-consumer-configure" COMMAND ${_tip_dependency_consumer_configure_command})
_tip_proof_run_step(
  NAME
  "dependency-consumer-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_dependency_consumer_build_dir}"
  --config
  Release)

file(
  WRITE "${_tip_modules_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.3)\n"
  "project(proof_cps_modules VERSION 1.0.0 LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/examples/check_cxx_modules_support.cmake\")\n"
  "check_cxx_modules_support(_tip_modules_supported)\n"
  "file(WRITE \"\${CMAKE_BINARY_DIR}/modules-supported.cmake\" \"set(TIP_MODULES_SUPPORTED \${_tip_modules_supported})\\n\")\n"
  "if(NOT _tip_modules_supported)\n"
  "  return()\n"
  "endif()\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "set(CMAKE_CXX_STANDARD 20)\n"
  "set(CMAKE_CXX_STANDARD_REQUIRED ON)\n"
  "set(CMAKE_CXX_EXTENSIONS OFF)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(cps_modules STATIC)\n"
  "target_compile_features(cps_modules PUBLIC cxx_std_20)\n"
  "target_sources(cps_modules PUBLIC FILE_SET CXX_MODULES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"src/tip_cps_module.cppm\")\n"
  "set_target_properties(cps_modules PROPERTIES CXX_SCAN_FOR_MODULES ON)\n"
  "target_install_package(cps_modules EXPORT_NAME CpsModules ALIAS_NAME modulelib MODULE_DESTINATION modules CPS CPS_PACKAGE_NAME CpsModules CPS_DESTINATION \"share/cps/cpsmodules\" CPS_CXX_MODULES_DIRECTORY cxx-modules CPS_LOWER_CASE_FILE)\n"
)
file(WRITE "${_tip_modules_source_dir}/src/tip_cps_module.cppm" "export module tip_cps_module;\nexport int tip_cps_module_value() { return 42; }\n")
set(_tip_modules_configure_command "${CMAKE_COMMAND}" -S "${_tip_modules_source_dir}" -B "${_tip_modules_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "modules-configure" COMMAND ${_tip_modules_configure_command})
include("${_tip_modules_build_dir}/modules-supported.cmake")
if(TIP_MODULES_SUPPORTED)
  _tip_proof_run_step(
    NAME
    "modules-build"
    COMMAND
    "${CMAKE_COMMAND}"
    --build
    "${_tip_modules_build_dir}"
    --config
    Release)
  _tip_proof_run_step(
    NAME
    "modules-install"
    COMMAND
    "${CMAKE_COMMAND}"
    --install
    "${_tip_modules_build_dir}"
    --config
    Release
    --prefix
    "${_tip_modules_install_prefix}")
  file(GLOB _tip_module_metadata_files "${_tip_modules_install_prefix}/share/cps/cpsmodules/cxx-modules/*.modules.json")
  list(LENGTH _tip_module_metadata_files _tip_module_metadata_file_count)
  if(NOT _tip_module_metadata_file_count EQUAL 1)
    _tip_proof_fail("Expected one installed CPS C++ module metadata file, got ${_tip_module_metadata_file_count}")
  endif()
  list(GET _tip_module_metadata_files 0 _tip_module_metadata_file)
  _tip_proof_assert_file_contains("${_tip_modules_install_prefix}/share/cps/cpsmodules/cpsmodules@release.cps" "cpp_module_metadata")
  _tip_proof_assert_file_contains("${_tip_modules_install_prefix}/share/cps/cpsmodules/cpsmodules@release.cps" "cxx-modules/")
  _tip_proof_assert_file_contains("${_tip_module_metadata_file}" "\"logical-name\" : \"tip_cps_module\"")
else()
  message(STATUS "[proof] Skipping CPS C++ module metadata proof because this toolchain does not support C++20 modules.")
endif()

file(
  WRITE "${_tip_project_inherit_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(CpsMetadataOwner VERSION 7.8.9 DESCRIPTION \"Owner metadata\" HOMEPAGE_URL \"https://owner.invalid\" LANGUAGES CXX)\n"
  "project(CurrentBuild VERSION 1.2.3 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(project_inherit STATIC src/project_inherit.cpp)\n"
  "target_install_package(project_inherit EXPORT_NAME ProjectInherit ALIAS_NAME project_component CPS CPS_PACKAGE_NAME ProjectInherit CPS_PROJECT CpsMetadataOwner CPS_COMPAT_VERSION 7.1.0 CPS_VERSION_SCHEMA simple CPS_DESTINATION \"share/cps/projectinherit\" CPS_LOWER_CASE_FILE)\n"
)
file(WRITE "${_tip_project_inherit_source_dir}/src/project_inherit.cpp" "int project_inherit_value() { return 8; }\n")
set(_tip_project_inherit_configure_command "${CMAKE_COMMAND}" -S "${_tip_project_inherit_source_dir}" -B "${_tip_project_inherit_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "project-inherit-configure" COMMAND ${_tip_project_inherit_configure_command})
_tip_proof_run_step(
  NAME
  "project-inherit-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_project_inherit_build_dir}"
  --config
  Release)
_tip_proof_run_step(
  NAME
  "project-inherit-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_project_inherit_build_dir}"
  --config
  Release
  --prefix
  "${_tip_project_inherit_install_prefix}")
set(_tip_project_inherit_cps_file "${_tip_project_inherit_install_prefix}/share/cps/projectinherit/projectinherit.cps")
_tip_proof_assert_json_string("${_tip_project_inherit_cps_file}" "version" "7.8.9")
_tip_proof_assert_json_string("${_tip_project_inherit_cps_file}" "compat_version" "7.1.0")
_tip_proof_assert_json_string("${_tip_project_inherit_cps_file}" "version_schema" "simple")
_tip_proof_assert_json_string("${_tip_project_inherit_cps_file}" "description" "Owner metadata")
_tip_proof_assert_json_string("${_tip_project_inherit_cps_file}" "website" "https://owner.invalid")
_tip_proof_assert_json_array("${_tip_project_inherit_cps_file}" "default_components" project_component)

file(
  WRITE "${_tip_appendix_version_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_cps_appendix_version VERSION 1.2.3 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(appendix_extra STATIC src/extra.cpp)\n"
  "target_install_package(appendix_extra EXPORT_NAME AppendixVersion VERSION \${PROJECT_VERSION} CPS CPS_PACKAGE_NAME AppendixVersion CPS_APPENDIX extras CPS_DESTINATION \"share/cps/appendixversion\" CPS_LOWER_CASE_FILE)\n"
)
file(WRITE "${_tip_appendix_version_source_dir}/src/extra.cpp" "int appendix_extra() { return 1; }\n")
set(_tip_appendix_version_configure_command "${CMAKE_COMMAND}" -S "${_tip_appendix_version_source_dir}" -B "${_tip_appendix_version_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "appendix-version-configure" COMMAND ${_tip_appendix_version_configure_command})
_tip_proof_run_step(
  NAME
  "appendix-version-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_appendix_version_build_dir}"
  --config
  Release)
_tip_proof_run_step(
  NAME
  "appendix-version-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_appendix_version_build_dir}"
  --config
  Release
  --prefix
  "${_tip_appendix_version_install_prefix}")
_tip_proof_assert_exists("${_tip_appendix_version_install_prefix}/share/cps/appendixversion/appendixversion-extras.cps")
_tip_proof_assert_not_exists("${_tip_appendix_version_install_prefix}/share/cps/appendixversion/appendixversion.cps")

file(
  WRITE "${_tip_bad_appendix_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_cps_bad_appendix VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(cps_appendix_core STATIC src/core.cpp)\n"
  "add_library(cps_appendix_extra STATIC src/extra.cpp)\n"
  "target_install_package(cps_appendix_core EXPORT_NAME bad_appendix_pkg CPS CPS_PACKAGE_NAME BadAppendix CPS_PROJECT proof_cps_bad_appendix)\n"
  "target_install_package(cps_appendix_extra EXPORT_NAME bad_appendix_pkg CPS CPS_PACKAGE_NAME BadAppendix CPS_APPENDIX extras)\n")
file(WRITE "${_tip_bad_appendix_source_dir}/src/core.cpp" "int cps_appendix_core() { return 1; }\n")
file(WRITE "${_tip_bad_appendix_source_dir}/src/extra.cpp" "int cps_appendix_extra() { return 2; }\n")

set(_tip_bad_appendix_configure_command "${CMAKE_COMMAND}" -S "${_tip_bad_appendix_source_dir}" -B "${_tip_bad_appendix_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "bad-appendix-configure" COMMAND ${_tip_bad_appendix_configure_command} EXPECT_CONTAINS "CPS_APPENDIX cannot be combined with")

file(
  WRITE "${_tip_bad_appendix_metadata_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n" "project(proof_cps_bad_appendix_metadata VERSION 1.0.0 LANGUAGES CXX)\n" "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n" "add_library(cps_appendix_metadata STATIC src/metadata.cpp)\n"
  "target_install_package(cps_appendix_metadata EXPORT_NAME bad_appendix_metadata CPS CPS_PACKAGE_NAME BadAppendixMetadata CPS_APPENDIX extras CPS_DESCRIPTION \"Invalid appendix metadata\")\n")
file(WRITE "${_tip_bad_appendix_metadata_source_dir}/src/metadata.cpp" "int cps_appendix_metadata() { return 1; }\n")

set(_tip_bad_appendix_metadata_configure_command "${CMAKE_COMMAND}" -S "${_tip_bad_appendix_metadata_source_dir}" -B "${_tip_bad_appendix_metadata_build_dir}" "-DCMAKE_BUILD_TYPE=Release"
                                                 ${_tip_toolchain_args})
_tip_proof_expect_failure(
  NAME
  "bad-appendix-metadata-configure"
  COMMAND
  ${_tip_bad_appendix_metadata_configure_command}
  EXPECT_CONTAINS
  "CPS_APPENDIX cannot be"
  "CPS_DESCRIPTION")

message(STATUS "[proof] CPS package info proof passed.")
