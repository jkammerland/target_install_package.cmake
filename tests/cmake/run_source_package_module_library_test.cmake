cmake_minimum_required(VERSION 3.25)

function(_tip_fail text)
  message(FATAL_ERROR "[source-package-module-library] ${text}")
endfunction()

function(_tip_run_step)
  set(options "")
  set(oneValueArgs NAME)
  set(multiValueArgs COMMAND)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_NAME)
    _tip_fail("_tip_run_step requires NAME")
  endif()
  if(NOT ARG_COMMAND)
    _tip_fail("_tip_run_step requires COMMAND")
  endif()

  execute_process(
    COMMAND ${ARG_COMMAND}
    RESULT_VARIABLE _result
    OUTPUT_VARIABLE _stdout
    ERROR_VARIABLE _stderr)

  if(NOT _result EQUAL 0)
    message(STATUS "[source-package-module-library] Step '${ARG_NAME}' failed.")
    if(NOT _stdout STREQUAL "")
      message(STATUS "[source-package-module-library][stdout]\n${_stdout}")
    endif()
    if(NOT _stderr STREQUAL "")
      message(STATUS "[source-package-module-library][stderr]\n${_stderr}")
    endif()
    _tip_fail("Step '${ARG_NAME}' exited with code ${_result}")
  endif()
endfunction()

function(_tip_assert_exists path)
  if(NOT EXISTS "${path}")
    _tip_fail("Expected path does not exist: ${path}")
  endif()
endfunction()

function(_tip_assert_file_contains path needle)
  _tip_assert_exists("${path}")
  file(READ "${path}" _content)
  string(FIND "${_content}" "${needle}" _match_index)
  if(_match_index EQUAL -1)
    _tip_fail("Expected to find '${needle}' in '${path}'")
  endif()
endfunction()

function(_tip_read_cache_entry cache_file key out_var)
  file(STRINGS "${cache_file}" _matching_lines REGEX "^${key}:")
  if(NOT _matching_lines)
    _tip_fail("Could not read '${key}' from '${cache_file}'")
  endif()
  list(GET _matching_lines 0 _entry)
  string(REGEX REPLACE "^[^=]*=" "" _value "${_entry}")
  set(${out_var}
      "${_value}"
      PARENT_SCOPE)
endfunction()

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_SOURCE_PACKAGE_MODULE_LIBRARY_TEST_ROOT)
  _tip_fail("TIP_SOURCE_PACKAGE_MODULE_LIBRARY_TEST_ROOT is required")
endif()

if(NOT DEFINED TIP_SOURCE_PACKAGE_MODULE_LIBRARY_TEST_CONFIG OR TIP_SOURCE_PACKAGE_MODULE_LIBRARY_TEST_CONFIG STREQUAL "")
  set(TIP_SOURCE_PACKAGE_MODULE_LIBRARY_TEST_CONFIG "Debug")
endif()

string(TOLOWER "${TIP_SOURCE_PACKAGE_MODULE_LIBRARY_TEST_CONFIG}" _tip_source_package_module_library_config_lower)

set(_fixture_source_dir "${TIP_REPO_ROOT}/tests/source-package-module-library")
set(_case_root "${TIP_SOURCE_PACKAGE_MODULE_LIBRARY_TEST_ROOT}/${_tip_source_package_module_library_config_lower}")
set(_build_dir "${_case_root}/build")
set(_install_prefix "${_case_root}/install")

file(REMOVE_RECURSE "${_case_root}")
file(MAKE_DIRECTORY "${_case_root}")

set(_configure_command "${CMAKE_COMMAND}" -S "${_fixture_source_dir}" -B "${_build_dir}" "-DTIP_REPO_ROOT=${TIP_REPO_ROOT}" "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_MODULE_LIBRARY_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-fixture" COMMAND ${_configure_command})
_tip_run_step(NAME "build-fixture" COMMAND "${CMAKE_COMMAND}" --build "${_build_dir}" --config "${TIP_SOURCE_PACKAGE_MODULE_LIBRARY_TEST_CONFIG}")
_tip_run_step(NAME "install-fixture" COMMAND "${CMAKE_COMMAND}" --install "${_build_dir}" --config "${TIP_SOURCE_PACKAGE_MODULE_LIBRARY_TEST_CONFIG}" --prefix "${_install_prefix}")

set(_cache_file "${_build_dir}/CMakeCache.txt")
_tip_assert_exists("${_cache_file}")
_tip_read_cache_entry("${_cache_file}" "CMAKE_INSTALL_DATADIR" _install_datadir)
_tip_read_cache_entry("${_cache_file}" "CMAKE_INSTALL_DATAROOTDIR" _install_datarootdir)
if(_install_datadir STREQUAL "")
  if(_install_datarootdir STREQUAL "")
    set(_install_datadir "share")
  else()
    set(_install_datadir "${_install_datarootdir}")
  endif()
endif()

set(_installed_source "${_install_prefix}/${_install_datadir}/source_plugin/src/source_plugin.cpp")
set(_installed_config "${_install_prefix}/${_install_datadir}/cmake/source_plugin/source_pluginConfig.cmake")
_tip_assert_exists("${_installed_source}")
_tip_assert_exists("${_installed_config}")

set(_consumer_dir "${_case_root}/consumer")
set(_consumer_build_dir "${_consumer_dir}/build")
file(MAKE_DIRECTORY "${_consumer_dir}")

file(
  WRITE
  "${_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_module_library_consumer LANGUAGES CXX)

find_package(source_plugin CONFIG REQUIRED)

get_target_property(_source_plugin_local_target SourcePlugin::source_plugin ALIASED_TARGET)
if(NOT _source_plugin_local_target)
  message(FATAL_ERROR "SourcePlugin::source_plugin is not an alias target")
endif()
get_target_property(_source_plugin_imported "${_source_plugin_local_target}" IMPORTED)
if(_source_plugin_imported)
  message(FATAL_ERROR "SourcePlugin::source_plugin resolved to an imported target")
endif()
get_target_property(_source_plugin_type "${_source_plugin_local_target}" TYPE)
get_target_property(_source_plugin_sources "${_source_plugin_local_target}" SOURCES)
file(WRITE "${CMAKE_BINARY_DIR}/source_plugin_type.txt" "${_source_plugin_type}\n")
file(WRITE "${CMAKE_BINARY_DIR}/source_plugin_sources.txt" "${_source_plugin_sources}\n")
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/source_plugin_file.txt" CONTENT "$<TARGET_FILE:${_source_plugin_local_target}>")

add_custom_target(source_package_module_library_consumer ALL DEPENDS ${_source_plugin_local_target})
]=])

set(_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_consumer_dir}"
    -B
    "${_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_MODULE_LIBRARY_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-consumer" COMMAND ${_consumer_configure_command})
_tip_run_step(NAME "build-consumer" COMMAND "${CMAKE_COMMAND}" --build "${_consumer_build_dir}" --config "${TIP_SOURCE_PACKAGE_MODULE_LIBRARY_TEST_CONFIG}")

set(_consumer_type_file "${_consumer_build_dir}/source_plugin_type.txt")
set(_consumer_sources_file "${_consumer_build_dir}/source_plugin_sources.txt")
set(_consumer_plugin_file "${_consumer_build_dir}/source_plugin_file.txt")
_tip_assert_file_contains("${_consumer_type_file}" "MODULE_LIBRARY")
_tip_assert_file_contains("${_consumer_sources_file}" "${_installed_source}")
_tip_assert_exists("${_consumer_plugin_file}")
file(READ "${_consumer_plugin_file}" _consumer_plugin_path)
string(STRIP "${_consumer_plugin_path}" _consumer_plugin_path)
_tip_assert_exists("${_consumer_plugin_path}")

message(STATUS "[source-package-module-library] Module-library source-package assertions passed.")
