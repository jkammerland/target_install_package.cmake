cmake_minimum_required(VERSION 3.25)

function(_tip_fail text)
  message(FATAL_ERROR "[source-package-export] ${text}")
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
    message(STATUS "[source-package-export] Step '${ARG_NAME}' failed.")
    if(NOT _stdout STREQUAL "")
      message(STATUS "[source-package-export][stdout]\n${_stdout}")
    endif()
    if(NOT _stderr STREQUAL "")
      message(STATUS "[source-package-export][stderr]\n${_stderr}")
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

function(_tip_assert_file_not_contains path needle)
  _tip_assert_exists("${path}")
  file(READ "${path}" _content)
  string(FIND "${_content}" "${needle}" _match_index)
  if(NOT _match_index EQUAL -1)
    _tip_fail("Did not expect to find '${needle}' in '${path}'")
  endif()
endfunction()

function(_tip_find_existing_path out_var)
  foreach(path IN LISTS ARGN)
    if(EXISTS "${path}")
      set(${out_var}
          "${path}"
          PARENT_SCOPE)
      return()
    endif()
  endforeach()

  _tip_fail("Expected one of these paths to exist: ${ARGN}")
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
if(NOT DEFINED TIP_SOURCE_PACKAGE_EXPORT_TEST_ROOT)
  _tip_fail("TIP_SOURCE_PACKAGE_EXPORT_TEST_ROOT is required")
endif()

if(NOT DEFINED TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG OR TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG STREQUAL "")
  set(TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG "Debug")
endif()

if(WIN32)
  set(_tip_executable_suffix ".exe")
else()
  set(_tip_executable_suffix "${CMAKE_EXECUTABLE_SUFFIX}")
endif()

string(TOLOWER "${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}" _tip_source_package_export_config_lower)

set(_fixture_source_dir "${TIP_REPO_ROOT}/tests/source-package-export")
set(_case_root "${TIP_SOURCE_PACKAGE_EXPORT_TEST_ROOT}/${_tip_source_package_export_config_lower}")
set(_build_dir "${_case_root}/build")
set(_install_prefix "${_case_root}/install")

file(REMOVE_RECURSE "${_case_root}")
file(MAKE_DIRECTORY "${_case_root}")

set(_configure_command "${CMAKE_COMMAND}" -S "${_fixture_source_dir}" -B "${_build_dir}" "-DTIP_REPO_ROOT=${TIP_REPO_ROOT}" "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")

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
_tip_run_step(
  NAME
  "build-fixture"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-fixture"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}"
  --prefix
  "${_install_prefix}")

set(_cache_file "${_build_dir}/CMakeCache.txt")
_tip_assert_exists("${_cache_file}")

_tip_read_cache_entry("${_cache_file}" "CMAKE_INSTALL_DATADIR" _install_datadir)
_tip_read_cache_entry("${_cache_file}" "CMAKE_INSTALL_DATAROOTDIR" _install_datarootdir)
_tip_read_cache_entry("${_cache_file}" "CMAKE_INSTALL_INCLUDEDIR" _install_includedir)

if(_install_datadir STREQUAL "")
  if(_install_datarootdir STREQUAL "")
    set(_install_datadir "share")
  else()
    set(_install_datadir "${_install_datarootdir}")
  endif()
endif()

set(_installed_source "${_install_prefix}/${_install_datadir}/source_sdk/src/algorithms.cpp")
set(_installed_header "${_install_prefix}/${_install_includedir}/source_sdk/sdk.hpp")
set(_installed_config "${_install_prefix}/${_install_datadir}/cmake/source_sdk/source_sdkConfig.cmake")

_tip_assert_exists("${_installed_source}")
_tip_assert_exists("${_installed_header}")
_tip_assert_exists("${_installed_config}")

set(_consumer_dir "${_case_root}/consumer")
set(_consumer_build_dir "${_consumer_dir}/build")
file(MAKE_DIRECTORY "${_consumer_dir}")

file(
  WRITE
  "${_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_export_consumer LANGUAGES CXX)

find_package(source_sdk CONFIG REQUIRED)

get_target_property(_source_sdk_interface_sources SourceSdk::export_algorithms INTERFACE_SOURCES)
if(NOT _source_sdk_interface_sources)
  message(FATAL_ERROR "SourceSdk::export_algorithms did not expose INTERFACE_SOURCES")
endif()
file(WRITE "${CMAKE_BINARY_DIR}/source_sdk_interface_sources.txt" "${_source_sdk_interface_sources}\n")

add_executable(source_package_export_consumer main.cpp)
target_compile_features(source_package_export_consumer PRIVATE cxx_std_17)
target_link_libraries(source_package_export_consumer PRIVATE SourceSdk::export_sdk)

if(WIN32)
  add_custom_command(
    TARGET source_package_export_consumer
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy -t $<TARGET_FILE_DIR:source_package_export_consumer> $<TARGET_RUNTIME_DLLS:source_package_export_consumer>
    COMMAND_EXPAND_LISTS)
endif()
]=])

file(
  WRITE
  "${_consumer_dir}/main.cpp"
  [=[
#include "source_sdk/sdk.hpp"

#include <vector>

int main() {
  const std::vector<int> values{1, 2, 3};
  const std::vector<int> calibrated = source_sdk::algorithms::calibrate(values);

  const bool edition_ok = source_sdk::runtime::edition() == "source-sdk";
  const bool size_ok = calibrated.size() == 3;
  const bool values_ok = calibrated[0] == 5 && calibrated[1] == 6 && calibrated[2] == 7;
  const bool score_ok = source_sdk::algorithms::score(values) == 18;

  return edition_ok && size_ok && values_ok && score_ok ? 0 : 1;
}
]=])

set(_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_consumer_dir}"
    -B
    "${_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")
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
_tip_run_step(
  NAME
  "build-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")

set(_consumer_interface_sources "${_consumer_build_dir}/source_sdk_interface_sources.txt")
_tip_assert_file_contains("${_consumer_interface_sources}" "${_installed_source}")
_tip_assert_file_not_contains("${_consumer_interface_sources}" "${_fixture_source_dir}/src/algorithms.cpp")

set(_consumer_executable_candidates
    "${_consumer_build_dir}/source_package_export_consumer${_tip_executable_suffix}"
    "${_consumer_build_dir}/${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}/source_package_export_consumer${_tip_executable_suffix}"
    "${_consumer_build_dir}/source_package_export_consumer"
    "${_consumer_build_dir}/${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}/source_package_export_consumer")
_tip_find_existing_path(_consumer_executable ${_consumer_executable_candidates})
_tip_run_step(NAME "run-consumer" COMMAND "${_consumer_executable}")

message(STATUS "[source-package-export] Shared export source-package assertions passed.")
