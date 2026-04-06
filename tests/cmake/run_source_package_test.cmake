cmake_minimum_required(VERSION 3.25)

function(_tip_fail text)
  message(FATAL_ERROR "[source-package] ${text}")
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
    message(STATUS "[source-package] Step '${ARG_NAME}' failed.")
    if(NOT _stdout STREQUAL "")
      message(STATUS "[source-package][stdout]\n${_stdout}")
    endif()
    if(NOT _stderr STREQUAL "")
      message(STATUS "[source-package][stderr]\n${_stderr}")
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
if(NOT DEFINED TIP_SOURCE_PACKAGE_TEST_ROOT)
  _tip_fail("TIP_SOURCE_PACKAGE_TEST_ROOT is required")
endif()

if(NOT DEFINED TIP_SOURCE_PACKAGE_TEST_CONFIG OR TIP_SOURCE_PACKAGE_TEST_CONFIG STREQUAL "")
  set(TIP_SOURCE_PACKAGE_TEST_CONFIG "Debug")
endif()

if(WIN32)
  set(_tip_executable_suffix ".exe")
else()
  set(_tip_executable_suffix "${CMAKE_EXECUTABLE_SUFFIX}")
endif()

string(TOLOWER "${TIP_SOURCE_PACKAGE_TEST_CONFIG}" _tip_source_package_config_lower)

set(_fixture_source_dir "${TIP_REPO_ROOT}/tests/source-package")
set(_case_root "${TIP_SOURCE_PACKAGE_TEST_ROOT}/${_tip_source_package_config_lower}")
set(_build_dir "${_case_root}/build")
set(_install_prefix "${_case_root}/install")

file(REMOVE_RECURSE "${_case_root}")
file(MAKE_DIRECTORY "${_case_root}")

set(_configure_command "${CMAKE_COMMAND}" -S "${_fixture_source_dir}" -B "${_build_dir}" "-DTIP_REPO_ROOT=${TIP_REPO_ROOT}" "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

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
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-fixture"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
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

set(_installed_source "${_install_prefix}/${_install_datadir}/source_package/src/source_package.cpp")
set(_installed_generated_build_interface_source "${_install_prefix}/${_install_datadir}/source_package/generated/source_package_build_interface.cpp")
set(_installed_generated_source "${_install_prefix}/${_install_datadir}/source_package/generated/source_package_generated.cpp")
set(_installed_platform_source_posix "${_install_prefix}/${_install_datadir}/source_package/src/source_package_platform_posix.cpp")
set(_installed_platform_source_windows "${_install_prefix}/${_install_datadir}/source_package/src/source_package_platform_windows.cpp")
set(_installed_header "${_install_prefix}/${_install_includedir}/source_package/source_package.hpp")
set(_installed_public_header "${_install_prefix}/${_install_includedir}/source_package_legacy.hpp")
set(_installed_config "${_install_prefix}/${_install_datadir}/cmake/source_package/source_packageConfig.cmake")
set(_installed_source_targets "${_install_prefix}/${_install_datadir}/cmake/source_package/source_packageSourceTargets.cmake")

_tip_assert_exists("${_installed_source}")
_tip_assert_exists("${_installed_generated_build_interface_source}")
_tip_assert_exists("${_installed_generated_source}")
_tip_assert_exists("${_installed_platform_source_posix}")
_tip_assert_exists("${_installed_platform_source_windows}")
_tip_assert_exists("${_installed_header}")
_tip_assert_exists("${_installed_public_header}")
_tip_assert_exists("${_installed_config}")
_tip_assert_exists("${_installed_source_targets}")

set(_consumer_dir "${_case_root}/consumer")
set(_consumer_build_dir "${_consumer_dir}/build")
file(MAKE_DIRECTORY "${_consumer_dir}")

file(
  WRITE
  "${_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_consumer LANGUAGES CXX)

set(BUILD_SHARED_LIBS ON)
find_package(source_package CONFIG REQUIRED)
unset(BUILD_SHARED_LIBS)

get_target_property(_source_package_local_target SourcePackage::source_package ALIASED_TARGET)
if(NOT _source_package_local_target)
  message(FATAL_ERROR "SourcePackage::source_package is not an alias target")
endif()
get_target_property(_source_package_imported "${_source_package_local_target}" IMPORTED)
if(_source_package_imported)
  message(FATAL_ERROR "SourcePackage::source_package resolved to an imported target")
endif()
get_target_property(_source_package_sources "${_source_package_local_target}" SOURCES)
if(NOT _source_package_sources)
  message(FATAL_ERROR "SourcePackage::source_package did not expose local SOURCES")
endif()
get_target_property(_source_package_type "${_source_package_local_target}" TYPE)
file(WRITE "${CMAKE_BINARY_DIR}/source_package_sources.txt" "${_source_package_sources}\n")
file(WRITE "${CMAKE_BINARY_DIR}/source_package_type.txt" "${_source_package_type}\n")

add_executable(source_package_consumer main.cpp)
target_compile_features(source_package_consumer PRIVATE cxx_std_17)
target_link_libraries(source_package_consumer PRIVATE SourcePackage::source_package)

if(WIN32)
  add_custom_command(
    TARGET source_package_consumer
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy -t $<TARGET_FILE_DIR:source_package_consumer> $<TARGET_RUNTIME_DLLS:source_package_consumer>
    COMMAND_EXPAND_LISTS)
endif()
]=])

file(
  WRITE
  "${_consumer_dir}/main.cpp"
  [=[
#include "source_package/source_package.hpp"
#include "source_package_legacy.hpp"

int main() {
  return source_package::add(19, 23) == 42 && source_package::legacy_marker() == 42 ? 0 : 1;
}
]=])

set(_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_consumer_dir}"
    -B
    "${_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
    "-DCMAKE_MESSAGE_LOG_LEVEL=DEBUG")
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

execute_process(
  COMMAND ${_consumer_configure_command}
  RESULT_VARIABLE _consumer_configure_result
  OUTPUT_VARIABLE _consumer_configure_stdout
  ERROR_VARIABLE _consumer_configure_stderr)
if(NOT _consumer_configure_result EQUAL 0)
  message(STATUS "[source-package] Step 'configure-consumer' failed.")
  if(NOT _consumer_configure_stdout STREQUAL "")
    message(STATUS "[source-package][stdout]\n${_consumer_configure_stdout}")
  endif()
  if(NOT _consumer_configure_stderr STREQUAL "")
    message(STATUS "[source-package][stderr]\n${_consumer_configure_stderr}")
  endif()
  _tip_fail("Step 'configure-consumer' exited with code ${_consumer_configure_result}")
endif()
_tip_run_step(
  NAME
  "build-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

set(_consumer_sources_file "${_consumer_build_dir}/source_package_sources.txt")
set(_consumer_type_file "${_consumer_build_dir}/source_package_type.txt")
_tip_assert_file_contains("${_consumer_sources_file}" "${_installed_source}")
_tip_assert_file_contains("${_consumer_sources_file}" "${_installed_generated_build_interface_source}")
_tip_assert_file_contains("${_consumer_sources_file}" "${_installed_generated_source}")
_tip_assert_file_contains("${_consumer_sources_file}" "${_install_prefix}/${_install_datadir}/source_package/src/source_package_platform_")
_tip_assert_file_not_contains("${_consumer_sources_file}" "${_fixture_source_dir}/src/source_package.cpp")
_tip_assert_file_not_contains("${_consumer_sources_file}" "${_build_dir}/generated/source_package_build_interface.cpp")
_tip_assert_file_not_contains("${_consumer_sources_file}" "${_build_dir}/generated/source_package_generated.cpp")
_tip_assert_file_contains("${_consumer_type_file}" "SHARED_LIBRARY")

set(_consumer_configure_output "${_consumer_configure_stdout}\n${_consumer_configure_stderr}")
string(FIND "${_consumer_configure_output}" "Recreated SourcePackage::source_package as SHARED_LIBRARY (BUILD_SHARED_LIBS=ON)" _consumer_debug_match)
if(_consumer_debug_match EQUAL -1)
  _tip_fail("Expected debug recreation message for shared source package")
endif()

_tip_assert_file_contains("${_installed_source_targets}" "PLATFORM_ID:Windows")
_tip_assert_file_contains("${_installed_source_targets}" "source_package_platform_windows.cpp")
_tip_assert_file_contains("${_installed_source_targets}" "source_package_platform_posix.cpp")

set(_consumer_executable_candidates
    "${_consumer_build_dir}/source_package_consumer${_tip_executable_suffix}"
    "${_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/source_package_consumer${_tip_executable_suffix}"
    "${_consumer_build_dir}/source_package_consumer"
    "${_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/source_package_consumer")
_tip_find_existing_path(_consumer_executable ${_consumer_executable_candidates})
_tip_run_step(NAME "run-consumer" COMMAND "${_consumer_executable}")

set(_plain_dir "${_case_root}/plain-add-library")
set(_plain_build_dir "${_plain_dir}/build")
set(_plain_install_prefix "${_plain_dir}/install")
file(MAKE_DIRECTORY "${_plain_dir}")

file(
  WRITE
  "${_plain_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_plain LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "file(MAKE_DIRECTORY \"${_plain_dir}/include/plain_pkg\")\n"
  "file(WRITE \"${_plain_dir}/include/plain_pkg/value.hpp\" \"#pragma once\\nint plain_value();\\n\")\n"
  "file(WRITE \"${_plain_dir}/plain.cpp\" \"#include \\\"plain_pkg/value.hpp\\\"\\nint plain_value(){return 17;}\\n\")\n"
  "add_library(plain STATIC plain.cpp)\n"
  "target_sources(plain PUBLIC FILE_SET HEADERS BASE_DIRS \"${_plain_dir}/include\" FILES \"${_plain_dir}/include/plain_pkg/value.hpp\")\n"
  "target_install_package(plain EXPORT_NAME plain_pkg NAMESPACE PlainPkg:: INCLUDE_SOURCES EXCLUSIVE)\n")

set(_plain_configure_command "${CMAKE_COMMAND}" -S "${_plain_dir}" -B "${_plain_build_dir}" "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _plain_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _plain_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _plain_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _plain_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _plain_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _plain_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _plain_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-plain" COMMAND ${_plain_configure_command})
_tip_run_step(NAME "build-plain" COMMAND "${CMAKE_COMMAND}" --build "${_plain_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-plain"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_plain_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_plain_install_prefix}")

set(_plain_cache_file "${_plain_build_dir}/CMakeCache.txt")
_tip_assert_exists("${_plain_cache_file}")
_tip_read_cache_entry("${_plain_cache_file}" "CMAKE_INSTALL_DATADIR" _plain_install_datadir)
_tip_read_cache_entry("${_plain_cache_file}" "CMAKE_INSTALL_DATAROOTDIR" _plain_install_datarootdir)
if(_plain_install_datadir STREQUAL "")
  if(_plain_install_datarootdir STREQUAL "")
    set(_plain_install_datadir "share")
  else()
    set(_plain_install_datadir "${_plain_install_datarootdir}")
  endif()
endif()

set(_plain_installed_source "${_plain_install_prefix}/${_plain_install_datadir}/plain_pkg/plain/plain.cpp")
_tip_assert_exists("${_plain_installed_source}")

set(_plain_consumer_dir "${_plain_dir}/consumer")
set(_plain_consumer_build_dir "${_plain_consumer_dir}/build")
file(MAKE_DIRECTORY "${_plain_consumer_dir}")

file(
  WRITE
  "${_plain_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_plain_consumer LANGUAGES CXX)

find_package(plain_pkg CONFIG REQUIRED)

get_target_property(_plain_local_target PlainPkg::plain ALIASED_TARGET)
if(NOT _plain_local_target)
  message(FATAL_ERROR "PlainPkg::plain is not an alias target")
endif()
get_target_property(_plain_sources "${_plain_local_target}" SOURCES)
if(NOT _plain_sources)
  message(FATAL_ERROR "PlainPkg::plain did not expose local SOURCES")
endif()
file(WRITE "${CMAKE_BINARY_DIR}/plain_sources.txt" "${_plain_sources}\n")

add_executable(plain_consumer main.cpp)
target_link_libraries(plain_consumer PRIVATE PlainPkg::plain)
]=])

file(
  WRITE
  "${_plain_consumer_dir}/main.cpp"
  [=[
#include "plain_pkg/value.hpp"

int main() {
  return plain_value() == 17 ? 0 : 1;
}
]=])

set(_plain_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_plain_consumer_dir}"
    -B
    "${_plain_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_plain_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _plain_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _plain_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _plain_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _plain_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _plain_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _plain_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _plain_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-plain-consumer" COMMAND ${_plain_consumer_configure_command})
_tip_run_step(
  NAME
  "build-plain-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_plain_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_assert_file_contains("${_plain_consumer_build_dir}/plain_sources.txt" "${_plain_installed_source}")
_tip_assert_file_not_contains("${_plain_consumer_build_dir}/plain_sources.txt" "${_plain_dir}/plain.cpp")

set(_plain_consumer_executable_candidates
    "${_plain_consumer_build_dir}/plain_consumer${_tip_executable_suffix}"
    "${_plain_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/plain_consumer${_tip_executable_suffix}"
    "${_plain_consumer_build_dir}/plain_consumer"
    "${_plain_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/plain_consumer")
_tip_find_existing_path(_plain_consumer_executable ${_plain_consumer_executable_candidates})
_tip_run_step(NAME "run-plain-consumer" COMMAND "${_plain_consumer_executable}")

set(_invalid_dir "${_case_root}/invalid")
set(_invalid_build_dir "${_invalid_dir}/build")
file(MAKE_DIRECTORY "${_invalid_dir}/src")

file(
  WRITE
  "${_invalid_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_invalid LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_executable(invalid src/invalid.cpp)\n"
  "target_install_package(invalid INCLUDE_SOURCES EXCLUSIVE)\n")
file(WRITE "${_invalid_dir}/src/invalid.cpp" "int invalid() { return 0; }\n")

set(_invalid_configure_command "${CMAKE_COMMAND}" -S "${_invalid_dir}" -B "${_invalid_build_dir}" "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _invalid_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _invalid_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _invalid_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _invalid_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _invalid_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _invalid_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _invalid_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

execute_process(
  COMMAND ${_invalid_configure_command}
  RESULT_VARIABLE _invalid_result
  OUTPUT_VARIABLE _invalid_stdout
  ERROR_VARIABLE _invalid_stderr)

if(_invalid_result EQUAL 0)
  _tip_fail("Expected non-library INCLUDE_SOURCES EXCLUSIVE configure to fail")
endif()

set(_invalid_output "${_invalid_stdout}\n${_invalid_stderr}")
string(FIND "${_invalid_output}" "supported only for library targets" _invalid_match_index)
if(_invalid_match_index EQUAL -1)
  _tip_fail("Expected validation error for non-library INCLUDE_SOURCES EXCLUSIVE usage")
endif()

set(_external_dep_dir "${_case_root}/external-dependency")
set(_external_dep_build_dir "${_external_dep_dir}/build")
file(MAKE_DIRECTORY "${_external_dep_dir}/include/repro")

file(
  WRITE
  "${_external_dep_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_external_dependency LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "find_package(Threads REQUIRED)\n"
  "file(WRITE \"${_external_dep_dir}/include/repro/user.hpp\" \"#pragma once\\nint external_dep_user();\\n\")\n"
  "file(WRITE \"${_external_dep_dir}/user.cpp\" \"#include \\\"repro/user.hpp\\\"\\nint external_dep_user(){return 0;}\\n\")\n"
  "add_library(external_dep STATIC)\n"
  "target_sources(external_dep PRIVATE \"${_external_dep_dir}/user.cpp\" PUBLIC FILE_SET HEADERS BASE_DIRS \"${_external_dep_dir}/include\" FILES \"${_external_dep_dir}/include/repro/user.hpp\")\n"
  "target_link_libraries(external_dep PRIVATE Threads::Threads)\n"
  "target_install_package(external_dep EXPORT_NAME external_dep NAMESPACE ExternalDep:: INCLUDE_SOURCES EXCLUSIVE)\n")

set(_external_dep_configure_command "${CMAKE_COMMAND}" -S "${_external_dep_dir}" -B "${_external_dep_build_dir}" "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _external_dep_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _external_dep_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _external_dep_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _external_dep_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _external_dep_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _external_dep_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _external_dep_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

execute_process(
  COMMAND ${_external_dep_configure_command}
  RESULT_VARIABLE _external_dep_result
  OUTPUT_VARIABLE _external_dep_stdout
  ERROR_VARIABLE _external_dep_stderr)

if(_external_dep_result EQUAL 0)
  _tip_fail("Expected missing PUBLIC_DEPENDENCIES for external imported target to fail")
endif()

set(_external_dep_output "${_external_dep_stdout}\n${_external_dep_stderr}")
string(FIND "${_external_dep_output}" "Threads::Threads" _external_dep_target_match)
if(_external_dep_target_match EQUAL -1)
  _tip_fail("Expected validation error naming the unresolved external imported target")
endif()
string(FIND "${_external_dep_output}" "PUBLIC_DEPENDENCIES" _external_dep_dependency_match)
if(_external_dep_dependency_match EQUAL -1)
  _tip_fail("Expected validation error suggesting the missing PUBLIC_DEPENDENCIES entry")
endif()

set(_helper_bypass_dir "${_case_root}/external-helper-bypass")
set(_helper_bypass_build_dir "${_helper_bypass_dir}/build")
file(MAKE_DIRECTORY "${_helper_bypass_dir}/include/repro" "${_helper_bypass_dir}/cmake")

file(
  WRITE
  "${_helper_bypass_dir}/cmake/helper.cmake"
  "set(REPRO_HELPER_LOADED TRUE)\n")

file(
  WRITE
  "${_helper_bypass_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_external_helper_bypass LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "find_package(Threads REQUIRED)\n"
  "file(WRITE \"${_helper_bypass_dir}/include/repro/user.hpp\" \"#pragma once\\nint helper_bypass_user();\\n\")\n"
  "file(WRITE \"${_helper_bypass_dir}/user.cpp\" \"#include \\\"repro/user.hpp\\\"\\nint helper_bypass_user(){return 11;}\\n\")\n"
  "add_library(helper_bypass STATIC)\n"
  "target_sources(helper_bypass PRIVATE \"${_helper_bypass_dir}/user.cpp\" PUBLIC FILE_SET HEADERS BASE_DIRS \"${_helper_bypass_dir}/include\" FILES \"${_helper_bypass_dir}/include/repro/user.hpp\")\n"
  "target_link_libraries(helper_bypass PRIVATE Threads::Threads)\n"
  "target_install_package(helper_bypass EXPORT_NAME helper_bypass NAMESPACE HelperBypass:: INCLUDE_ON_FIND_PACKAGE \"${_helper_bypass_dir}/cmake/helper.cmake\" INCLUDE_SOURCES EXCLUSIVE)\n")

set(_helper_bypass_configure_command "${CMAKE_COMMAND}" -S "${_helper_bypass_dir}" -B "${_helper_bypass_build_dir}"
                                     "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _helper_bypass_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _helper_bypass_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _helper_bypass_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _helper_bypass_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _helper_bypass_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _helper_bypass_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _helper_bypass_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

execute_process(
  COMMAND ${_helper_bypass_configure_command}
  RESULT_VARIABLE _helper_bypass_result
  OUTPUT_VARIABLE _helper_bypass_stdout
  ERROR_VARIABLE _helper_bypass_stderr)

if(_helper_bypass_result EQUAL 0)
  _tip_fail("Expected INCLUDE_ON_FIND_PACKAGE without PUBLIC_DEPENDENCIES to fail for external imported targets")
endif()

set(_helper_bypass_output "${_helper_bypass_stdout}\n${_helper_bypass_stderr}")
string(FIND "${_helper_bypass_output}" "PUBLIC_DEPENDENCIES" _helper_bypass_dependency_match)
if(_helper_bypass_dependency_match EQUAL -1)
  _tip_fail("Expected helper-bypass validation error to still require PUBLIC_DEPENDENCIES")
endif()
string(FIND "${_helper_bypass_output}" "INCLUDE_ON_FIND_PACKAGE does not waive" _helper_bypass_helper_match)
if(_helper_bypass_helper_match EQUAL -1)
  _tip_fail("Expected helper-bypass validation error to explain that INCLUDE_ON_FIND_PACKAGE does not waive dependency declarations")
endif()

set(_namespace_dep_dir "${_case_root}/namespace-mismatch-dependency")
set(_namespace_dep_build_dir "${_namespace_dep_dir}/build")
file(MAKE_DIRECTORY "${_namespace_dep_dir}/include/repro")

file(
  WRITE
  "${_namespace_dep_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_namespace_mismatch_dependency LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(unofficial::sqlite3::sqlite3 INTERFACE IMPORTED)\n"
  "file(WRITE \"${_namespace_dep_dir}/include/repro/user.hpp\" \"#pragma once\\nint namespace_dep_user();\\n\")\n"
  "file(WRITE \"${_namespace_dep_dir}/user.cpp\" \"#include \\\"repro/user.hpp\\\"\\nint namespace_dep_user(){return 15;}\\n\")\n"
  "add_library(namespace_dep STATIC)\n"
  "target_sources(namespace_dep PRIVATE \"${_namespace_dep_dir}/user.cpp\" PUBLIC FILE_SET HEADERS BASE_DIRS \"${_namespace_dep_dir}/include\" FILES \"${_namespace_dep_dir}/include/repro/user.hpp\")\n"
  "target_link_libraries(namespace_dep PRIVATE unofficial::sqlite3::sqlite3)\n"
  "target_install_package(namespace_dep EXPORT_NAME namespace_dep NAMESPACE NamespaceDep:: PUBLIC_DEPENDENCIES \"unofficial-sqlite3 CONFIG REQUIRED\" INCLUDE_SOURCES EXCLUSIVE)\n")

set(_namespace_dep_configure_command "${CMAKE_COMMAND}" -S "${_namespace_dep_dir}" -B "${_namespace_dep_build_dir}"
                                     "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _namespace_dep_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _namespace_dep_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _namespace_dep_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _namespace_dep_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _namespace_dep_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _namespace_dep_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _namespace_dep_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-namespace-mismatch-dependency" COMMAND ${_namespace_dep_configure_command})

set(_root_dep_dir "${_case_root}/root-package-dependency")
set(_root_dep_build_dir "${_root_dep_dir}/build")
file(MAKE_DIRECTORY "${_root_dep_dir}/include/repro")

file(
  WRITE
  "${_root_dep_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_root_package_dependency LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(OpenSSL::SSL INTERFACE IMPORTED)\n"
  "file(WRITE \"${_root_dep_dir}/include/repro/user.hpp\" \"#pragma once\\nint root_dep_user();\\n\")\n"
  "file(WRITE \"${_root_dep_dir}/user.cpp\" \"#include \\\"repro/user.hpp\\\"\\nint root_dep_user(){return 19;}\\n\")\n"
  "add_library(root_dep STATIC)\n"
  "target_sources(root_dep PRIVATE \"${_root_dep_dir}/user.cpp\" PUBLIC FILE_SET HEADERS BASE_DIRS \"${_root_dep_dir}/include\" FILES \"${_root_dep_dir}/include/repro/user.hpp\")\n"
  "target_link_libraries(root_dep PRIVATE OpenSSL::SSL)\n"
  "target_install_package(root_dep EXPORT_NAME root_dep NAMESPACE RootDep:: PUBLIC_DEPENDENCIES \"OpenSSL REQUIRED\" INCLUDE_SOURCES EXCLUSIVE)\n")

set(_root_dep_configure_command "${CMAKE_COMMAND}" -S "${_root_dep_dir}" -B "${_root_dep_build_dir}"
                                "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _root_dep_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _root_dep_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _root_dep_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _root_dep_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _root_dep_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _root_dep_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _root_dep_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-root-package-dependency" COMMAND ${_root_dep_configure_command})

set(_unrelated_dep_dir "${_case_root}/unrelated-dependency")
set(_unrelated_dep_build_dir "${_unrelated_dep_dir}/build")
file(MAKE_DIRECTORY "${_unrelated_dep_dir}/include/repro")

file(
  WRITE
  "${_unrelated_dep_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_unrelated_dependency LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(Threads::Threads INTERFACE IMPORTED)\n"
  "file(WRITE \"${_unrelated_dep_dir}/include/repro/user.hpp\" \"#pragma once\\nint unrelated_dep_user();\\n\")\n"
  "file(WRITE \"${_unrelated_dep_dir}/user.cpp\" \"#include \\\"repro/user.hpp\\\"\\nint unrelated_dep_user(){return 17;}\\n\")\n"
  "add_library(unrelated_dep STATIC)\n"
  "target_sources(unrelated_dep PRIVATE \"${_unrelated_dep_dir}/user.cpp\" PUBLIC FILE_SET HEADERS BASE_DIRS \"${_unrelated_dep_dir}/include\" FILES \"${_unrelated_dep_dir}/include/repro/user.hpp\")\n"
  "target_link_libraries(unrelated_dep PRIVATE Threads::Threads)\n"
  "target_install_package(unrelated_dep EXPORT_NAME unrelated_dep NAMESPACE UnrelatedDep:: PUBLIC_DEPENDENCIES \"ZLIB REQUIRED\" INCLUDE_SOURCES EXCLUSIVE)\n")

set(_unrelated_dep_configure_command "${CMAKE_COMMAND}" -S "${_unrelated_dep_dir}" -B "${_unrelated_dep_build_dir}"
                                     "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _unrelated_dep_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _unrelated_dep_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _unrelated_dep_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _unrelated_dep_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _unrelated_dep_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _unrelated_dep_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _unrelated_dep_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

execute_process(
  COMMAND ${_unrelated_dep_configure_command}
  RESULT_VARIABLE _unrelated_dep_result
  OUTPUT_VARIABLE _unrelated_dep_stdout
  ERROR_VARIABLE _unrelated_dep_stderr)

if(_unrelated_dep_result EQUAL 0)
  _tip_fail("Expected unrelated PUBLIC_DEPENDENCIES entry to fail validation for external imported targets")
endif()

set(_unrelated_dep_output "${_unrelated_dep_stdout}\n${_unrelated_dep_stderr}")
string(FIND "${_unrelated_dep_output}" "Threads::Threads" _unrelated_dep_target_match)
if(_unrelated_dep_target_match EQUAL -1)
  _tip_fail("Expected unrelated-dependency validation error to name the missing imported target")
endif()
string(FIND "${_unrelated_dep_output}" "no matching PUBLIC_DEPENDENCIES entry was provided" _unrelated_dep_dependency_match)
if(_unrelated_dep_dependency_match EQUAL -1)
  _tip_fail("Expected unrelated-dependency validation error to reject the unrelated PUBLIC_DEPENDENCIES entry")
endif()

set(_component_mismatch_dir "${_case_root}/component-mismatch-dependency")
set(_component_mismatch_build_dir "${_component_mismatch_dir}/build")
file(MAKE_DIRECTORY "${_component_mismatch_dir}/include/repro")

file(
  WRITE
  "${_component_mismatch_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_component_mismatch_dependency LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(Foo::Alpha INTERFACE IMPORTED)\n"
  "file(WRITE \"${_component_mismatch_dir}/include/repro/user.hpp\" \"#pragma once\\nint component_dep_user();\\n\")\n"
  "file(WRITE \"${_component_mismatch_dir}/user.cpp\" \"#include \\\"repro/user.hpp\\\"\\nint component_dep_user(){return 18;}\\n\")\n"
  "add_library(component_dep STATIC)\n"
  "target_sources(component_dep PRIVATE \"${_component_mismatch_dir}/user.cpp\" PUBLIC FILE_SET HEADERS BASE_DIRS \"${_component_mismatch_dir}/include\" FILES \"${_component_mismatch_dir}/include/repro/user.hpp\")\n"
  "target_link_libraries(component_dep PRIVATE Foo::Alpha)\n"
  "target_install_package(component_dep EXPORT_NAME component_dep NAMESPACE ComponentDep:: PUBLIC_DEPENDENCIES \"Foo COMPONENTS Beta\" INCLUDE_SOURCES EXCLUSIVE)\n")

set(_component_mismatch_configure_command "${CMAKE_COMMAND}" -S "${_component_mismatch_dir}" -B "${_component_mismatch_build_dir}"
                                          "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _component_mismatch_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _component_mismatch_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _component_mismatch_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _component_mismatch_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _component_mismatch_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _component_mismatch_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _component_mismatch_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

execute_process(
  COMMAND ${_component_mismatch_configure_command}
  RESULT_VARIABLE _component_mismatch_result
  OUTPUT_VARIABLE _component_mismatch_stdout
  ERROR_VARIABLE _component_mismatch_stderr)

if(_component_mismatch_result EQUAL 0)
  _tip_fail("Expected mismatched PUBLIC_DEPENDENCIES component declaration to fail validation")
endif()

set(_component_mismatch_output "${_component_mismatch_stdout}\n${_component_mismatch_stderr}")
string(FIND "${_component_mismatch_output}" "Foo::Alpha" _component_mismatch_target_match)
if(_component_mismatch_target_match EQUAL -1)
  _tip_fail("Expected component-mismatch validation error to name the missing imported target")
endif()
string(FIND "${_component_mismatch_output}" "PUBLIC_DEPENDENCIES \"Foo\"" _component_mismatch_dependency_match)
if(_component_mismatch_dependency_match EQUAL -1)
  _tip_fail("Expected component-mismatch validation error to reject the wrong component declaration")
endif()

set(_multi_component_dep_dir "${_case_root}/multi-component-dependency")
set(_multi_component_dep_build_dir "${_multi_component_dep_dir}/build")
file(MAKE_DIRECTORY "${_multi_component_dep_dir}/include/repro")

file(
  WRITE
  "${_multi_component_dep_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_multi_component_dependency LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(Pkg::filesystem INTERFACE IMPORTED)\n"
  "file(WRITE \"${_multi_component_dep_dir}/include/repro/user.hpp\" \"#pragma once\\nint multi_component_dep_user();\\n\")\n"
  "file(WRITE \"${_multi_component_dep_dir}/user.cpp\" \"#include \\\"repro/user.hpp\\\"\\nint multi_component_dep_user(){return 21;}\\n\")\n"
  "add_library(multi_component_dep STATIC)\n"
  "target_sources(multi_component_dep PRIVATE \"${_multi_component_dep_dir}/user.cpp\" PUBLIC FILE_SET HEADERS BASE_DIRS \"${_multi_component_dep_dir}/include\" FILES \"${_multi_component_dep_dir}/include/repro/user.hpp\")\n"
  "target_link_libraries(multi_component_dep PRIVATE Pkg::filesystem)\n"
  "target_install_package(multi_component_dep EXPORT_NAME multi_component_dep NAMESPACE MultiComponentDep:: PUBLIC_DEPENDENCIES \"Pkg COMPONENTS system filesystem\" INCLUDE_SOURCES EXCLUSIVE)\n")

set(_multi_component_dep_configure_command "${CMAKE_COMMAND}" -S "${_multi_component_dep_dir}" -B "${_multi_component_dep_build_dir}"
                                           "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _multi_component_dep_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _multi_component_dep_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _multi_component_dep_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _multi_component_dep_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _multi_component_dep_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _multi_component_dep_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _multi_component_dep_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-multi-component-dependency" COMMAND ${_multi_component_dep_configure_command})

if(CMAKE_SYSTEM_NAME STREQUAL "Windows")
  set(_disabled_platform_name "Linux")
else()
  set(_disabled_platform_name "Windows")
endif()

set(_platform_dep_dir "${_case_root}/platform-conditional-dependency")
set(_platform_dep_build_dir "${_platform_dep_dir}/build")
file(MAKE_DIRECTORY "${_platform_dep_dir}/include/repro")

file(
  WRITE
  "${_platform_dep_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_platform_conditional_dependency LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(Foo::Foo INTERFACE IMPORTED)\n"
  "file(WRITE \"${_platform_dep_dir}/include/repro/user.hpp\" \"#pragma once\\nint platform_dep_user();\\n\")\n"
  "file(WRITE \"${_platform_dep_dir}/user.cpp\" \"#include \\\"repro/user.hpp\\\"\\nint platform_dep_user(){return 16;}\\n\")\n"
  "add_library(platform_dep STATIC)\n"
  "target_sources(platform_dep PRIVATE \"${_platform_dep_dir}/user.cpp\" PUBLIC FILE_SET HEADERS BASE_DIRS \"${_platform_dep_dir}/include\" FILES \"${_platform_dep_dir}/include/repro/user.hpp\")\n"
  "target_link_libraries(platform_dep PRIVATE \"$<$<PLATFORM_ID:${_disabled_platform_name}>:Foo::Foo>\")\n"
  "target_install_package(platform_dep EXPORT_NAME platform_dep NAMESPACE PlatformDep:: INCLUDE_SOURCES EXCLUSIVE)\n")

set(_platform_dep_configure_command "${CMAKE_COMMAND}" -S "${_platform_dep_dir}" -B "${_platform_dep_build_dir}"
                                    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _platform_dep_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _platform_dep_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _platform_dep_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _platform_dep_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _platform_dep_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _platform_dep_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _platform_dep_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-platform-conditional-dependency" COMMAND ${_platform_dep_configure_command})

set(_local_helper_dir "${_case_root}/local-helper-target")
set(_local_helper_build_dir "${_local_helper_dir}/build")
file(MAKE_DIRECTORY "${_local_helper_dir}")

file(
  WRITE
  "${_local_helper_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_local_helper LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "file(WRITE \"${_local_helper_dir}/helper.cpp\" \"int helper_value(){return 9;}\\n\")\n"
  "file(WRITE \"${_local_helper_dir}/user.cpp\" \"int local_user(){return 9;}\\n\")\n"
  "add_library(local_helper STATIC helper.cpp)\n"
  "add_library(local_user STATIC user.cpp)\n"
  "target_link_libraries(local_user PRIVATE local_helper)\n"
  "target_install_package(local_user EXPORT_NAME local_user_pkg NAMESPACE LocalUserPkg:: INCLUDE_SOURCES EXCLUSIVE)\n")

set(_local_helper_configure_command "${CMAKE_COMMAND}" -S "${_local_helper_dir}" -B "${_local_helper_build_dir}" "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _local_helper_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _local_helper_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _local_helper_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _local_helper_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _local_helper_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _local_helper_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _local_helper_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

execute_process(
  COMMAND ${_local_helper_configure_command}
  RESULT_VARIABLE _local_helper_result
  OUTPUT_VARIABLE _local_helper_stdout
  ERROR_VARIABLE _local_helper_stderr)

if(_local_helper_result EQUAL 0)
  _tip_fail("Expected non-exported local helper target to fail for INCLUDE_SOURCES EXCLUSIVE")
endif()

set(_local_helper_output "${_local_helper_stdout}\n${_local_helper_stderr}")
string(FIND "${_local_helper_output}" "local_helper" _local_helper_target_match)
if(_local_helper_target_match EQUAL -1)
  _tip_fail("Expected validation error naming the non-exported local helper target")
endif()
string(FIND "${_local_helper_output}" "not part of the same export" _local_helper_message_match)
if(_local_helper_message_match EQUAL -1)
  _tip_fail("Expected validation error explaining the local helper target is not part of the export")
endif()

set(_unsupported_source_dir "${_case_root}/unsupported-source-kind")
set(_unsupported_source_build_dir "${_unsupported_source_dir}/build")
file(MAKE_DIRECTORY "${_unsupported_source_dir}/include/repro" "${_unsupported_source_dir}/src")

file(
  WRITE
  "${_unsupported_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_unsupported_source_kind LANGUAGES C ASM)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "file(WRITE \"${_unsupported_source_dir}/include/repro/value.h\" \"#pragma once\\nint asm_value(void);\\n\")\n"
  "file(WRITE \"${_unsupported_source_dir}/src/value.S\" \".globl asm_value\\nasm_value:\\n  ret\\n\")\n"
  "add_library(asm_value STATIC src/value.S)\n"
  "target_sources(asm_value PUBLIC FILE_SET HEADERS BASE_DIRS \"${_unsupported_source_dir}/include\" FILES \"${_unsupported_source_dir}/include/repro/value.h\")\n"
  "target_install_package(asm_value EXPORT_NAME asm_value_pkg NAMESPACE AsmValuePkg:: INCLUDE_SOURCES EXCLUSIVE)\n")

set(_unsupported_source_configure_command "${CMAKE_COMMAND}" -S "${_unsupported_source_dir}" -B "${_unsupported_source_build_dir}"
                                          "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _unsupported_source_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _unsupported_source_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _unsupported_source_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _unsupported_source_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _unsupported_source_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _unsupported_source_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _unsupported_source_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

execute_process(
  COMMAND ${_unsupported_source_configure_command}
  RESULT_VARIABLE _unsupported_source_result
  OUTPUT_VARIABLE _unsupported_source_stdout
  ERROR_VARIABLE _unsupported_source_stderr)

if(_unsupported_source_result EQUAL 0)
  _tip_fail("Expected unsupported implementation source kind to fail for INCLUDE_SOURCES EXCLUSIVE")
endif()

set(_unsupported_source_output "${_unsupported_source_stdout}\n${_unsupported_source_stderr}")
string(FIND "${_unsupported_source_output}" "unsupported extension '.S'" _unsupported_source_extension_match)
if(_unsupported_source_extension_match EQUAL -1)
  _tip_fail("Expected unsupported source validation error to name the unsupported extension")
endif()
string(FIND "${_unsupported_source_output}" "value.S" _unsupported_source_file_match)
if(_unsupported_source_file_match EQUAL -1)
  _tip_fail("Expected unsupported source validation error to name the offending source file")
endif()

set(_outside_source_dir "${_case_root}/outside-source-dir")
set(_outside_source_build_dir "${_outside_source_dir}/build")
set(_outside_source_install_prefix "${_outside_source_dir}/install")
file(MAKE_DIRECTORY "${_outside_source_dir}/common/src" "${_outside_source_dir}/lib/include/outside_pkg")

file(
  WRITE
  "${_outside_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_outside_source_dir LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_subdirectory(lib)\n")
file(
  WRITE
  "${_outside_source_dir}/lib/CMakeLists.txt"
  "add_library(shared_bits STATIC ../common/src/value.cpp)\n"
  "target_sources(shared_bits PUBLIC FILE_SET HEADERS BASE_DIRS \"${_outside_source_dir}/lib/include\" FILES \"include/outside_pkg/value.hpp\")\n"
  "target_compile_features(shared_bits PUBLIC cxx_std_17)\n"
  "target_install_package(shared_bits EXPORT_NAME outside_pkg NAMESPACE OutsidePkg:: INCLUDE_SOURCES EXCLUSIVE)\n")
file(
  WRITE
  "${_outside_source_dir}/lib/include/outside_pkg/value.hpp"
  "#pragma once\n"
  "int outside_value();\n")
file(
  WRITE
  "${_outside_source_dir}/common/src/value.cpp"
  "#include \"outside_pkg/value.hpp\"\n"
  "int outside_value(){return 27;}\n")

set(_outside_source_configure_command "${CMAKE_COMMAND}" -S "${_outside_source_dir}" -B "${_outside_source_build_dir}"
                                      "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _outside_source_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _outside_source_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _outside_source_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _outside_source_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _outside_source_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _outside_source_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _outside_source_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-outside-source-dir" COMMAND ${_outside_source_configure_command})
_tip_run_step(NAME "build-outside-source-dir" COMMAND "${CMAKE_COMMAND}" --build "${_outside_source_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-outside-source-dir"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_outside_source_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_outside_source_install_prefix}")

set(_outside_source_cache_file "${_outside_source_build_dir}/CMakeCache.txt")
_tip_assert_exists("${_outside_source_cache_file}")
_tip_read_cache_entry("${_outside_source_cache_file}" "CMAKE_INSTALL_DATADIR" _outside_source_install_datadir)
_tip_read_cache_entry("${_outside_source_cache_file}" "CMAKE_INSTALL_DATAROOTDIR" _outside_source_install_datarootdir)
if(_outside_source_install_datadir STREQUAL "")
  if(_outside_source_install_datarootdir STREQUAL "")
    set(_outside_source_install_datadir "share")
  else()
    set(_outside_source_install_datadir "${_outside_source_install_datarootdir}")
  endif()
endif()

set(_outside_installed_source "${_outside_source_install_prefix}/${_outside_source_install_datadir}/outside_pkg/shared_bits/common/src/value.cpp")
_tip_assert_exists("${_outside_installed_source}")

set(_outside_source_consumer_dir "${_outside_source_dir}/consumer")
set(_outside_source_consumer_build_dir "${_outside_source_consumer_dir}/build")
file(MAKE_DIRECTORY "${_outside_source_consumer_dir}")

file(
  WRITE
  "${_outside_source_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_outside_source_dir_consumer LANGUAGES CXX)

find_package(outside_pkg CONFIG REQUIRED)

get_target_property(_outside_local_target OutsidePkg::shared_bits ALIASED_TARGET)
get_target_property(_outside_sources "${_outside_local_target}" SOURCES)
file(WRITE "${CMAKE_BINARY_DIR}/outside_sources.txt" "${_outside_sources}\n")

add_executable(outside_source_consumer main.cpp)
target_link_libraries(outside_source_consumer PRIVATE OutsidePkg::shared_bits)
]=])

file(
  WRITE
  "${_outside_source_consumer_dir}/main.cpp"
  [=[
#include "outside_pkg/value.hpp"

int main() {
  return outside_value() == 27 ? 0 : 1;
}
]=])

set(_outside_source_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_outside_source_consumer_dir}"
    -B
    "${_outside_source_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_outside_source_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _outside_source_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _outside_source_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _outside_source_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _outside_source_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _outside_source_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _outside_source_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _outside_source_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-outside-source-dir-consumer" COMMAND ${_outside_source_consumer_configure_command})
_tip_run_step(
  NAME
  "build-outside-source-dir-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_outside_source_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_assert_file_contains("${_outside_source_consumer_build_dir}/outside_sources.txt" "${_outside_installed_source}")

set(_outside_source_consumer_executable_candidates
    "${_outside_source_consumer_build_dir}/outside_source_consumer${_tip_executable_suffix}"
    "${_outside_source_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/outside_source_consumer${_tip_executable_suffix}"
    "${_outside_source_consumer_build_dir}/outside_source_consumer"
    "${_outside_source_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/outside_source_consumer")
_tip_find_existing_path(_outside_source_consumer_executable ${_outside_source_consumer_executable_candidates})
_tip_run_step(NAME "run-outside-source-dir-consumer" COMMAND "${_outside_source_consumer_executable}")

set(_dead_link_dir "${_case_root}/dead-link-helper")
set(_dead_link_build_dir "${_dead_link_dir}/build")
set(_dead_link_install_prefix "${_dead_link_dir}/install")
file(MAKE_DIRECTORY "${_dead_link_dir}")

file(
  WRITE
  "${_dead_link_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_dead_link_helper LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "file(WRITE \"${_dead_link_dir}/helper.cpp\" \"int dead_helper_value(){return 0;}\\n\")\n"
  "file(WRITE \"${_dead_link_dir}/user.cpp\" \"int dead_link_user(){return 5;}\\n\")\n"
  "add_library(dead_helper STATIC helper.cpp)\n"
  "add_library(dead_user STATIC user.cpp)\n"
  "target_link_libraries(dead_user PRIVATE \"$<$<BOOL:0>:dead_helper>\")\n"
  "target_install_package(dead_user EXPORT_NAME dead_user_pkg NAMESPACE DeadUserPkg:: INCLUDE_SOURCES EXCLUSIVE)\n")

set(_dead_link_configure_command "${CMAKE_COMMAND}" -S "${_dead_link_dir}" -B "${_dead_link_build_dir}" "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _dead_link_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _dead_link_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _dead_link_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _dead_link_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _dead_link_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _dead_link_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _dead_link_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-dead-link-helper" COMMAND ${_dead_link_configure_command})
_tip_run_step(NAME "build-dead-link-helper" COMMAND "${CMAKE_COMMAND}" --build "${_dead_link_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-dead-link-helper"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_dead_link_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_dead_link_install_prefix}")

set(_dead_link_consumer_dir "${_dead_link_dir}/consumer")
set(_dead_link_consumer_build_dir "${_dead_link_consumer_dir}/build")
file(MAKE_DIRECTORY "${_dead_link_consumer_dir}")

file(
  WRITE
  "${_dead_link_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_dead_link_helper_consumer LANGUAGES CXX)

find_package(dead_user_pkg CONFIG REQUIRED)

add_executable(dead_link_consumer main.cpp)
target_link_libraries(dead_link_consumer PRIVATE DeadUserPkg::dead_user)
]=])

file(
  WRITE
  "${_dead_link_consumer_dir}/main.cpp"
  [=[
int dead_link_user();

int main() {
  return dead_link_user() == 5 ? 0 : 1;
}
]=])

set(_dead_link_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_dead_link_consumer_dir}"
    -B
    "${_dead_link_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_dead_link_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _dead_link_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _dead_link_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _dead_link_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _dead_link_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _dead_link_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _dead_link_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _dead_link_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-dead-link-helper-consumer" COMMAND ${_dead_link_consumer_configure_command})
_tip_run_step(
  NAME
  "build-dead-link-helper-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_dead_link_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

set(_dead_link_consumer_executable_candidates
    "${_dead_link_consumer_build_dir}/dead_link_consumer${_tip_executable_suffix}"
    "${_dead_link_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/dead_link_consumer${_tip_executable_suffix}"
    "${_dead_link_consumer_build_dir}/dead_link_consumer"
    "${_dead_link_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/dead_link_consumer")
_tip_find_existing_path(_dead_link_consumer_executable ${_dead_link_consumer_executable_candidates})
_tip_run_step(NAME "run-dead-link-helper-consumer" COMMAND "${_dead_link_consumer_executable}")

set(_external_helper_dir "${_case_root}/external-helper")
set(_external_helper_build_dir "${_external_helper_dir}/build")
set(_external_helper_install_prefix "${_external_helper_dir}/install")
file(MAKE_DIRECTORY "${_external_helper_dir}/include/repro" "${_external_helper_dir}/cmake")

file(
  WRITE
  "${_external_helper_dir}/cmake/load_threads.cmake"
  "find_dependency(Threads)\n")

file(
  WRITE
  "${_external_helper_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_external_helper LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "find_package(Threads REQUIRED)\n"
  "file(WRITE \"${_external_helper_dir}/include/repro/user.hpp\" \"#pragma once\\nint external_helper_user();\\n\")\n"
  "file(WRITE \"${_external_helper_dir}/helper.cpp\" \"int external_helper_build_only(){return 0;}\\n\")\n"
  "file(WRITE \"${_external_helper_dir}/user.cpp\" \"#include \\\"repro/user.hpp\\\"\\nint external_helper_user(){return 3;}\\n\")\n"
  "add_library(build_only_helper STATIC helper.cpp)\n"
  "add_library(external_helper STATIC)\n"
  "target_sources(external_helper PRIVATE \"${_external_helper_dir}/user.cpp\" PUBLIC FILE_SET HEADERS BASE_DIRS \"${_external_helper_dir}/include\" FILES \"${_external_helper_dir}/include/repro/user.hpp\")\n"
  "target_link_libraries(external_helper PUBLIC \"$<BUILD_INTERFACE:build_only_helper>\" \"$<INSTALL_INTERFACE:Threads::Threads>\")\n"
  "target_install_package(external_helper EXPORT_NAME external_helper NAMESPACE ExternalHelper:: PUBLIC_DEPENDENCIES \"Threads REQUIRED\" INCLUDE_ON_FIND_PACKAGE \"${_external_helper_dir}/cmake/load_threads.cmake\" INCLUDE_SOURCES EXCLUSIVE)\n")

set(_external_helper_configure_command "${CMAKE_COMMAND}" -S "${_external_helper_dir}" -B "${_external_helper_build_dir}" "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _external_helper_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _external_helper_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _external_helper_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _external_helper_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _external_helper_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _external_helper_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _external_helper_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-external-helper" COMMAND ${_external_helper_configure_command})
_tip_run_step(NAME "build-external-helper" COMMAND "${CMAKE_COMMAND}" --build "${_external_helper_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-external-helper"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_external_helper_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_external_helper_install_prefix}")

set(_external_helper_installed_config "${_external_helper_install_prefix}/share/cmake/external_helper/external_helperConfig.cmake")
_tip_assert_exists("${_external_helper_installed_config}")
_tip_assert_file_contains("${_external_helper_installed_config}" "find_dependency(Threads REQUIRED)")

set(_external_helper_consumer_dir "${_external_helper_dir}/consumer")
set(_external_helper_consumer_build_dir "${_external_helper_consumer_dir}/build")
file(MAKE_DIRECTORY "${_external_helper_consumer_dir}")

file(
  WRITE
  "${_external_helper_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_external_helper_consumer LANGUAGES CXX)

find_package(external_helper CONFIG REQUIRED)

get_target_property(_external_helper_local_target ExternalHelper::external_helper ALIASED_TARGET)
if(NOT _external_helper_local_target)
  message(FATAL_ERROR "ExternalHelper::external_helper is not an alias target")
endif()
get_target_property(_external_helper_links "${_external_helper_local_target}" LINK_LIBRARIES)
get_target_property(_external_helper_interface_links "${_external_helper_local_target}" INTERFACE_LINK_LIBRARIES)
file(WRITE "${CMAKE_BINARY_DIR}/external_helper_links.txt" "${_external_helper_links}\n")
file(WRITE "${CMAKE_BINARY_DIR}/external_helper_interface_links.txt" "${_external_helper_interface_links}\n")

add_executable(external_helper_consumer main.cpp)
target_link_libraries(external_helper_consumer PRIVATE ExternalHelper::external_helper)
]=])

file(
  WRITE
  "${_external_helper_consumer_dir}/main.cpp"
  [=[
#include "repro/user.hpp"

int main() {
  return external_helper_user() == 3 ? 0 : 1;
}
]=])

set(_external_helper_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_external_helper_consumer_dir}"
    -B
    "${_external_helper_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_external_helper_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _external_helper_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _external_helper_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _external_helper_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _external_helper_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _external_helper_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _external_helper_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _external_helper_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-external-helper-consumer" COMMAND ${_external_helper_consumer_configure_command})
_tip_assert_file_contains("${_external_helper_consumer_build_dir}/external_helper_links.txt" "Threads::Threads")
_tip_assert_file_contains("${_external_helper_consumer_build_dir}/external_helper_interface_links.txt" "Threads::Threads")
_tip_assert_file_not_contains("${_external_helper_consumer_build_dir}/external_helper_links.txt" "build_only_helper")
_tip_assert_file_not_contains("${_external_helper_consumer_build_dir}/external_helper_interface_links.txt" "build_only_helper")
_tip_assert_file_not_contains("${_external_helper_consumer_build_dir}/external_helper_links.txt" "BUILD_INTERFACE")
_tip_assert_file_not_contains("${_external_helper_consumer_build_dir}/external_helper_interface_links.txt" "BUILD_INTERFACE")
_tip_assert_file_not_contains("${_external_helper_consumer_build_dir}/external_helper_links.txt" "INSTALL_INTERFACE")
_tip_assert_file_not_contains("${_external_helper_consumer_build_dir}/external_helper_interface_links.txt" "INSTALL_INTERFACE")
_tip_run_step(
  NAME
  "build-external-helper-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_external_helper_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

set(_external_helper_consumer_executable_candidates
    "${_external_helper_consumer_build_dir}/external_helper_consumer${_tip_executable_suffix}"
    "${_external_helper_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/external_helper_consumer${_tip_executable_suffix}"
    "${_external_helper_consumer_build_dir}/external_helper_consumer"
    "${_external_helper_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/external_helper_consumer")
_tip_find_existing_path(_external_helper_consumer_executable ${_external_helper_consumer_executable_candidates})
_tip_run_step(NAME "run-external-helper-consumer" COMMAND "${_external_helper_consumer_executable}")

set(_multi_target_dir "${_case_root}/multi-target-export")
set(_multi_target_build_dir "${_multi_target_dir}/build")
set(_multi_target_install_prefix "${_multi_target_dir}/install")
file(MAKE_DIRECTORY
     "${_multi_target_dir}/first/include/multi_pkg"
     "${_multi_target_dir}/first/src"
     "${_multi_target_dir}/second/include/multi_pkg"
     "${_multi_target_dir}/second/src")

file(
  WRITE
  "${_multi_target_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_multi_target LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_subdirectory(first)\n"
  "add_subdirectory(second)\n"
  "target_install_package(first EXPORT_NAME multi_pkg NAMESPACE MultiPkg:: INCLUDE_SOURCES EXCLUSIVE)\n"
  "target_install_package(second EXPORT_NAME multi_pkg NAMESPACE MultiPkg:: INCLUDE_SOURCES EXCLUSIVE)\n")

file(
  WRITE
  "${_multi_target_dir}/first/CMakeLists.txt"
  "add_library(first STATIC src/value.cpp)\n"
  "target_sources(first PUBLIC FILE_SET HEADERS BASE_DIRS \"${_multi_target_dir}/first/include\" FILES \"include/multi_pkg/first.hpp\")\n"
  "target_compile_features(first PUBLIC cxx_std_17)\n")
file(
  WRITE
  "${_multi_target_dir}/first/include/multi_pkg/first.hpp"
  "#pragma once\n"
  "int first_value();\n")
file(
  WRITE
  "${_multi_target_dir}/first/src/value.cpp"
  "#include \"multi_pkg/first.hpp\"\n"
  "int first_value(){return 11;}\n")

file(
  WRITE
  "${_multi_target_dir}/second/CMakeLists.txt"
  "add_library(second STATIC src/value.cpp)\n"
  "target_sources(second PUBLIC FILE_SET HEADERS BASE_DIRS \"${_multi_target_dir}/second/include\" FILES \"include/multi_pkg/second.hpp\")\n"
  "target_compile_features(second PUBLIC cxx_std_17)\n")
file(
  WRITE
  "${_multi_target_dir}/second/include/multi_pkg/second.hpp"
  "#pragma once\n"
  "int second_value();\n")
file(
  WRITE
  "${_multi_target_dir}/second/src/value.cpp"
  "#include \"multi_pkg/second.hpp\"\n"
  "int second_value(){return 29;}\n")

set(_multi_target_configure_command "${CMAKE_COMMAND}" -S "${_multi_target_dir}" -B "${_multi_target_build_dir}" "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _multi_target_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _multi_target_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _multi_target_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _multi_target_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _multi_target_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _multi_target_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _multi_target_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-multi-target" COMMAND ${_multi_target_configure_command})
_tip_run_step(NAME "build-multi-target" COMMAND "${CMAKE_COMMAND}" --build "${_multi_target_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-multi-target"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_multi_target_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_multi_target_install_prefix}")

set(_multi_target_cache_file "${_multi_target_build_dir}/CMakeCache.txt")
_tip_assert_exists("${_multi_target_cache_file}")
_tip_read_cache_entry("${_multi_target_cache_file}" "CMAKE_INSTALL_DATADIR" _multi_target_install_datadir)
_tip_read_cache_entry("${_multi_target_cache_file}" "CMAKE_INSTALL_DATAROOTDIR" _multi_target_install_datarootdir)
if(_multi_target_install_datadir STREQUAL "")
  if(_multi_target_install_datarootdir STREQUAL "")
    set(_multi_target_install_datadir "share")
  else()
    set(_multi_target_install_datadir "${_multi_target_install_datarootdir}")
  endif()
endif()

set(_first_installed_source "${_multi_target_install_prefix}/${_multi_target_install_datadir}/multi_pkg/first/src/value.cpp")
set(_second_installed_source "${_multi_target_install_prefix}/${_multi_target_install_datadir}/multi_pkg/second/src/value.cpp")
set(_legacy_colliding_source "${_multi_target_install_prefix}/${_multi_target_install_datadir}/multi_pkg/src/value.cpp")
_tip_assert_exists("${_first_installed_source}")
_tip_assert_exists("${_second_installed_source}")
if(EXISTS "${_legacy_colliding_source}")
  _tip_fail("Did not expect shared export source payload to collapse into ${_legacy_colliding_source}")
endif()

set(_multi_target_consumer_dir "${_multi_target_dir}/consumer")
set(_multi_target_consumer_build_dir "${_multi_target_consumer_dir}/build")
file(MAKE_DIRECTORY "${_multi_target_consumer_dir}")

file(
  WRITE
  "${_multi_target_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_multi_target_consumer LANGUAGES CXX)

find_package(multi_pkg CONFIG REQUIRED)

get_target_property(_first_local_target MultiPkg::first ALIASED_TARGET)
get_target_property(_second_local_target MultiPkg::second ALIASED_TARGET)
if(NOT _first_local_target OR NOT _second_local_target)
  message(FATAL_ERROR "Expected source-backed local targets for MultiPkg::first and MultiPkg::second")
endif()
get_target_property(_first_sources "${_first_local_target}" SOURCES)
get_target_property(_second_sources "${_second_local_target}" SOURCES)
file(WRITE "${CMAKE_BINARY_DIR}/first_sources.txt" "${_first_sources}\n")
file(WRITE "${CMAKE_BINARY_DIR}/second_sources.txt" "${_second_sources}\n")

add_executable(multi_target_consumer main.cpp)
target_link_libraries(multi_target_consumer PRIVATE MultiPkg::first MultiPkg::second)
]=])

file(
  WRITE
  "${_multi_target_consumer_dir}/main.cpp"
  [=[
#include "multi_pkg/first.hpp"
#include "multi_pkg/second.hpp"

int main() {
  return first_value() == 11 && second_value() == 29 ? 0 : 1;
}
]=])

set(_multi_target_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_multi_target_consumer_dir}"
    -B
    "${_multi_target_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_multi_target_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _multi_target_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _multi_target_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _multi_target_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _multi_target_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _multi_target_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _multi_target_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _multi_target_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-multi-target-consumer" COMMAND ${_multi_target_consumer_configure_command})
_tip_run_step(
  NAME
  "build-multi-target-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_multi_target_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_assert_file_contains("${_multi_target_consumer_build_dir}/first_sources.txt" "${_first_installed_source}")
_tip_assert_file_contains("${_multi_target_consumer_build_dir}/second_sources.txt" "${_second_installed_source}")
_tip_assert_file_not_contains("${_multi_target_consumer_build_dir}/first_sources.txt" "${_second_installed_source}")
_tip_assert_file_not_contains("${_multi_target_consumer_build_dir}/second_sources.txt" "${_first_installed_source}")

set(_multi_target_consumer_executable_candidates
    "${_multi_target_consumer_build_dir}/multi_target_consumer${_tip_executable_suffix}"
    "${_multi_target_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/multi_target_consumer${_tip_executable_suffix}"
    "${_multi_target_consumer_build_dir}/multi_target_consumer"
    "${_multi_target_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/multi_target_consumer")
_tip_find_existing_path(_multi_target_consumer_executable ${_multi_target_consumer_executable_candidates})
_tip_run_step(NAME "run-multi-target-consumer" COMMAND "${_multi_target_consumer_executable}")

set(_interface_source_dir "${_case_root}/interface-sources")
set(_interface_source_build_dir "${_interface_source_dir}/build")
set(_interface_source_install_prefix "${_interface_source_dir}/install")
file(MAKE_DIRECTORY "${_interface_source_dir}/include/iface_pkg" "${_interface_source_dir}/src")

file(
  WRITE
  "${_interface_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_interface_sources LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(iface INTERFACE)\n"
  "target_sources(iface INTERFACE src/value.cpp)\n"
  "target_sources(iface INTERFACE FILE_SET HEADERS BASE_DIRS \"${_interface_source_dir}/include\" FILES \"include/iface_pkg/value.hpp\")\n"
  "target_compile_features(iface INTERFACE cxx_std_17)\n"
  "target_install_package(iface EXPORT_NAME iface_pkg NAMESPACE IfacePkg:: INCLUDE_SOURCES EXCLUSIVE)\n")
file(
  WRITE
  "${_interface_source_dir}/include/iface_pkg/value.hpp"
  "#pragma once\n"
  "int iface_value();\n")
file(
  WRITE
  "${_interface_source_dir}/src/value.cpp"
  "#include \"iface_pkg/value.hpp\"\n"
  "int iface_value(){return 31;}\n")

set(_interface_source_configure_command "${CMAKE_COMMAND}" -S "${_interface_source_dir}" -B "${_interface_source_build_dir}"
                                        "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _interface_source_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _interface_source_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _interface_source_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _interface_source_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _interface_source_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _interface_source_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _interface_source_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-interface-sources" COMMAND ${_interface_source_configure_command})
_tip_run_step(NAME "build-interface-sources" COMMAND "${CMAKE_COMMAND}" --build "${_interface_source_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-interface-sources"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_interface_source_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_interface_source_install_prefix}")

set(_interface_source_cache_file "${_interface_source_build_dir}/CMakeCache.txt")
_tip_assert_exists("${_interface_source_cache_file}")
_tip_read_cache_entry("${_interface_source_cache_file}" "CMAKE_INSTALL_DATADIR" _interface_source_install_datadir)
_tip_read_cache_entry("${_interface_source_cache_file}" "CMAKE_INSTALL_DATAROOTDIR" _interface_source_install_datarootdir)
if(_interface_source_install_datadir STREQUAL "")
  if(_interface_source_install_datarootdir STREQUAL "")
    set(_interface_source_install_datadir "share")
  else()
    set(_interface_source_install_datadir "${_interface_source_install_datarootdir}")
  endif()
endif()

set(_interface_installed_source "${_interface_source_install_prefix}/${_interface_source_install_datadir}/iface_pkg/iface/src/value.cpp")
_tip_assert_exists("${_interface_installed_source}")

set(_interface_consumer_dir "${_interface_source_dir}/consumer")
set(_interface_consumer_build_dir "${_interface_consumer_dir}/build")
file(MAKE_DIRECTORY "${_interface_consumer_dir}")

file(
  WRITE
  "${_interface_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_interface_sources_consumer LANGUAGES CXX)

find_package(iface_pkg CONFIG REQUIRED)

get_target_property(_iface_local_target IfacePkg::iface ALIASED_TARGET)
if(NOT _iface_local_target)
  message(FATAL_ERROR "IfacePkg::iface is not an alias target")
endif()
get_target_property(_iface_type "${_iface_local_target}" TYPE)
get_target_property(_iface_sources "${_iface_local_target}" INTERFACE_SOURCES)
if(NOT _iface_sources)
  message(FATAL_ERROR "IfacePkg::iface did not expose INTERFACE_SOURCES")
endif()
file(WRITE "${CMAKE_BINARY_DIR}/iface_type.txt" "${_iface_type}\n")
file(WRITE "${CMAKE_BINARY_DIR}/iface_sources.txt" "${_iface_sources}\n")

add_executable(interface_sources_consumer main.cpp)
target_link_libraries(interface_sources_consumer PRIVATE IfacePkg::iface)
]=])

file(
  WRITE
  "${_interface_consumer_dir}/main.cpp"
  [=[
#include "iface_pkg/value.hpp"

int main() {
  return iface_value() == 31 ? 0 : 1;
}
]=])

set(_interface_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_interface_consumer_dir}"
    -B
    "${_interface_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_interface_source_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _interface_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _interface_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _interface_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _interface_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _interface_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _interface_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _interface_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-interface-sources-consumer" COMMAND ${_interface_consumer_configure_command})
_tip_run_step(
  NAME
  "build-interface-sources-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_interface_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_assert_file_contains("${_interface_consumer_build_dir}/iface_type.txt" "INTERFACE_LIBRARY")
_tip_assert_file_contains("${_interface_consumer_build_dir}/iface_sources.txt" "${_interface_installed_source}")
_tip_assert_file_not_contains("${_interface_consumer_build_dir}/iface_sources.txt" "${_interface_source_dir}/src/value.cpp")

set(_interface_consumer_executable_candidates
    "${_interface_consumer_build_dir}/interface_sources_consumer${_tip_executable_suffix}"
    "${_interface_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/interface_sources_consumer${_tip_executable_suffix}"
    "${_interface_consumer_build_dir}/interface_sources_consumer"
    "${_interface_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/interface_sources_consumer")
_tip_find_existing_path(_interface_consumer_executable ${_interface_consumer_executable_candidates})
_tip_run_step(NAME "run-interface-sources-consumer" COMMAND "${_interface_consumer_executable}")

set(_alias_collision_dir "${_case_root}/alias-collision")
set(_alias_collision_build_dir "${_alias_collision_dir}/build")
set(_alias_collision_install_prefix "${_alias_collision_dir}/install")
file(MAKE_DIRECTORY "${_alias_collision_dir}/include/alias_pkg" "${_alias_collision_dir}/src")

file(
  WRITE
  "${_alias_collision_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_alias_collision LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(dash_impl STATIC src/dash.cpp)\n"
  "target_sources(dash_impl PUBLIC FILE_SET HEADERS BASE_DIRS \"${_alias_collision_dir}/include\" FILES \"include/alias_pkg/dash.hpp\")\n"
  "add_library(underscore_impl STATIC src/underscore.cpp)\n"
  "target_sources(underscore_impl PUBLIC FILE_SET HEADERS BASE_DIRS \"${_alias_collision_dir}/include\" FILES \"include/alias_pkg/underscore.hpp\")\n"
  "target_install_package(dash_impl EXPORT_NAME alias_pkg NAMESPACE AliasPkg:: ALIAS_NAME foo-bar INCLUDE_SOURCES EXCLUSIVE)\n"
  "target_install_package(underscore_impl EXPORT_NAME alias_pkg NAMESPACE AliasPkg:: ALIAS_NAME foo_bar INCLUDE_SOURCES EXCLUSIVE)\n")
file(
  WRITE
  "${_alias_collision_dir}/include/alias_pkg/dash.hpp"
  "#pragma once\n"
  "int dash_value();\n")
file(
  WRITE
  "${_alias_collision_dir}/include/alias_pkg/underscore.hpp"
  "#pragma once\n"
  "int underscore_value();\n")
file(
  WRITE
  "${_alias_collision_dir}/src/dash.cpp"
  "#include \"alias_pkg/dash.hpp\"\n"
  "int dash_value(){return 41;}\n")
file(
  WRITE
  "${_alias_collision_dir}/src/underscore.cpp"
  "#include \"alias_pkg/underscore.hpp\"\n"
  "int underscore_value(){return 43;}\n")

set(_alias_collision_configure_command "${CMAKE_COMMAND}" -S "${_alias_collision_dir}" -B "${_alias_collision_build_dir}"
                                       "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _alias_collision_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _alias_collision_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _alias_collision_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _alias_collision_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _alias_collision_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _alias_collision_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _alias_collision_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-alias-collision" COMMAND ${_alias_collision_configure_command})
_tip_run_step(NAME "build-alias-collision" COMMAND "${CMAKE_COMMAND}" --build "${_alias_collision_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-alias-collision"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_alias_collision_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_alias_collision_install_prefix}")

set(_alias_collision_consumer_dir "${_alias_collision_dir}/consumer")
set(_alias_collision_consumer_build_dir "${_alias_collision_consumer_dir}/build")
file(MAKE_DIRECTORY "${_alias_collision_consumer_dir}")

file(
  WRITE
  "${_alias_collision_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_alias_collision_consumer LANGUAGES CXX)

find_package(alias_pkg CONFIG REQUIRED)

get_target_property(_dash_local_target AliasPkg::foo-bar ALIASED_TARGET)
get_target_property(_underscore_local_target AliasPkg::foo_bar ALIASED_TARGET)
if(NOT _dash_local_target OR NOT _underscore_local_target)
  message(FATAL_ERROR "Expected both alias-backed local targets")
endif()
file(WRITE "${CMAKE_BINARY_DIR}/dash_local_target.txt" "${_dash_local_target}\n")
file(WRITE "${CMAKE_BINARY_DIR}/underscore_local_target.txt" "${_underscore_local_target}\n")

add_executable(alias_collision_consumer main.cpp)
target_link_libraries(alias_collision_consumer PRIVATE AliasPkg::foo-bar AliasPkg::foo_bar)
]=])

file(
  WRITE
  "${_alias_collision_consumer_dir}/main.cpp"
  [=[
#include "alias_pkg/dash.hpp"
#include "alias_pkg/underscore.hpp"

int main() {
  return dash_value() == 41 && underscore_value() == 43 ? 0 : 1;
}
]=])

set(_alias_collision_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_alias_collision_consumer_dir}"
    -B
    "${_alias_collision_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_alias_collision_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _alias_collision_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _alias_collision_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _alias_collision_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _alias_collision_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _alias_collision_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _alias_collision_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _alias_collision_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-alias-collision-consumer" COMMAND ${_alias_collision_consumer_configure_command})
_tip_run_step(
  NAME
  "build-alias-collision-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_alias_collision_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

file(READ "${_alias_collision_consumer_build_dir}/dash_local_target.txt" _dash_local_target_value)
file(READ "${_alias_collision_consumer_build_dir}/underscore_local_target.txt" _underscore_local_target_value)
string(STRIP "${_dash_local_target_value}" _dash_local_target_value)
string(STRIP "${_underscore_local_target_value}" _underscore_local_target_value)
if(_dash_local_target_value STREQUAL _underscore_local_target_value)
  _tip_fail("Expected distinct recreated local targets for aliases foo-bar and foo_bar")
endif()

set(_alias_collision_consumer_executable_candidates
    "${_alias_collision_consumer_build_dir}/alias_collision_consumer${_tip_executable_suffix}"
    "${_alias_collision_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/alias_collision_consumer${_tip_executable_suffix}"
    "${_alias_collision_consumer_build_dir}/alias_collision_consumer"
    "${_alias_collision_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/alias_collision_consumer")
_tip_find_existing_path(_alias_collision_consumer_executable ${_alias_collision_consumer_executable_candidates})
_tip_run_step(NAME "run-alias-collision-consumer" COMMAND "${_alias_collision_consumer_executable}")

set(_link_collision_dir "${_case_root}/link-collision")
set(_link_collision_build_dir "${_link_collision_dir}/build")
set(_link_collision_install_prefix "${_link_collision_dir}/install")
file(MAKE_DIRECTORY "${_link_collision_dir}/include/collide_pkg" "${_link_collision_dir}/src")

file(
  WRITE
  "${_link_collision_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_link_collision LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(foo-bar STATIC src/foo-bar.cpp)\n"
  "target_sources(foo-bar PUBLIC FILE_SET HEADERS BASE_DIRS \"${_link_collision_dir}/include\" FILES \"include/collide_pkg/a.hpp\")\n"
  "add_library(foo_bar STATIC src/foo_bar.cpp)\n"
  "target_sources(foo_bar PUBLIC FILE_SET HEADERS BASE_DIRS \"${_link_collision_dir}/include\" FILES \"include/collide_pkg/b.hpp\")\n"
  "add_library(use_me STATIC src/use_me.cpp)\n"
  "target_sources(use_me PUBLIC FILE_SET HEADERS BASE_DIRS \"${_link_collision_dir}/include\" FILES \"include/collide_pkg/use_me.hpp\")\n"
  "target_link_libraries(use_me PUBLIC foo-bar)\n"
  "target_install_package(foo-bar EXPORT_NAME collide_pkg NAMESPACE Collide:: INCLUDE_SOURCES EXCLUSIVE)\n"
  "target_install_package(foo_bar EXPORT_NAME collide_pkg NAMESPACE Collide:: INCLUDE_SOURCES EXCLUSIVE)\n"
  "target_install_package(use_me EXPORT_NAME collide_pkg NAMESPACE Collide:: INCLUDE_SOURCES EXCLUSIVE)\n")
file(
  WRITE
  "${_link_collision_dir}/include/collide_pkg/a.hpp"
  "#pragma once\n"
  "int a();\n")
file(
  WRITE
  "${_link_collision_dir}/include/collide_pkg/b.hpp"
  "#pragma once\n"
  "int b();\n")
file(
  WRITE
  "${_link_collision_dir}/include/collide_pkg/use_me.hpp"
  "#pragma once\n"
  "int use_me_value();\n")
file(
  WRITE
  "${_link_collision_dir}/src/foo-bar.cpp"
  "#include \"collide_pkg/a.hpp\"\n"
  "int a(){return 11;}\n")
file(
  WRITE
  "${_link_collision_dir}/src/foo_bar.cpp"
  "#include \"collide_pkg/b.hpp\"\n"
  "int b(){return 13;}\n")
file(
  WRITE
  "${_link_collision_dir}/src/use_me.cpp"
  "#include \"collide_pkg/use_me.hpp\"\n"
  "#include \"collide_pkg/a.hpp\"\n"
  "int use_me_value(){return a();}\n")

set(_link_collision_configure_command "${CMAKE_COMMAND}" -S "${_link_collision_dir}" -B "${_link_collision_build_dir}"
                                      "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _link_collision_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _link_collision_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _link_collision_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _link_collision_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _link_collision_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _link_collision_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _link_collision_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-link-collision" COMMAND ${_link_collision_configure_command})
_tip_run_step(NAME "build-link-collision" COMMAND "${CMAKE_COMMAND}" --build "${_link_collision_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-link-collision"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_link_collision_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_link_collision_install_prefix}")

set(_link_collision_consumer_dir "${_link_collision_dir}/consumer")
set(_link_collision_consumer_build_dir "${_link_collision_consumer_dir}/build")
file(MAKE_DIRECTORY "${_link_collision_consumer_dir}")

file(
  WRITE
  "${_link_collision_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_link_collision_consumer LANGUAGES CXX)

find_package(collide_pkg CONFIG REQUIRED)

get_target_property(_use_local_target Collide::use_me ALIASED_TARGET)
if(NOT _use_local_target)
  message(FATAL_ERROR "Collide::use_me is not an alias target")
endif()
get_target_property(_use_links "${_use_local_target}" LINK_LIBRARIES)
get_target_property(_use_interface_links "${_use_local_target}" INTERFACE_LINK_LIBRARIES)
file(WRITE "${CMAKE_BINARY_DIR}/use_links.txt" "${_use_links}\n")
file(WRITE "${CMAKE_BINARY_DIR}/use_interface_links.txt" "${_use_interface_links}\n")

add_executable(link_collision_consumer main.cpp)
target_link_libraries(link_collision_consumer PRIVATE Collide::use_me)
]=])

file(
  WRITE
  "${_link_collision_consumer_dir}/main.cpp"
  [=[
#include "collide_pkg/use_me.hpp"

int main() {
  return use_me_value() == 11 ? 0 : 1;
}
]=])

set(_link_collision_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_link_collision_consumer_dir}"
    -B
    "${_link_collision_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_link_collision_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _link_collision_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _link_collision_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _link_collision_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _link_collision_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _link_collision_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _link_collision_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _link_collision_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-link-collision-consumer" COMMAND ${_link_collision_consumer_configure_command})
_tip_run_step(
  NAME
  "build-link-collision-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_link_collision_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

_tip_assert_file_not_contains("${_link_collision_consumer_build_dir}/use_links.txt" "Collide::foo_bar")
_tip_assert_file_contains("${_link_collision_consumer_build_dir}/use_interface_links.txt" "Collide::foo-bar")
_tip_assert_file_not_contains("${_link_collision_consumer_build_dir}/use_interface_links.txt" "Collide::foo_bar")

set(_link_collision_consumer_executable_candidates
    "${_link_collision_consumer_build_dir}/link_collision_consumer${_tip_executable_suffix}"
    "${_link_collision_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/link_collision_consumer${_tip_executable_suffix}"
    "${_link_collision_consumer_build_dir}/link_collision_consumer"
    "${_link_collision_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/link_collision_consumer")
_tip_find_existing_path(_link_collision_consumer_executable ${_link_collision_consumer_executable_candidates})
_tip_run_step(NAME "run-link-collision-consumer" COMMAND "${_link_collision_consumer_executable}")

set(_conditional_include_dir "${_case_root}/conditional-include")
set(_conditional_include_build_dir "${_conditional_include_dir}/build")
set(_conditional_include_install_prefix "${_conditional_include_dir}/install")
file(MAKE_DIRECTORY "${_conditional_include_dir}/include/cond_pkg" "${_conditional_include_dir}/private" "${_conditional_include_dir}/src")

file(
  WRITE
  "${_conditional_include_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_conditional_include LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(cond STATIC src/cond.cpp)\n"
  "target_sources(cond PUBLIC FILE_SET HEADERS BASE_DIRS \"${_conditional_include_dir}/include\" FILES \"include/cond_pkg/cond.hpp\")\n"
  "target_sources(cond PRIVATE FILE_SET private_headers TYPE HEADERS BASE_DIRS \"${_conditional_include_dir}/private\" FILES \"private/private.hpp\")\n"
  "target_include_directories(cond PRIVATE \"$<$<BOOL:1>:${_conditional_include_dir}/private>\")\n"
  "target_install_package(cond EXPORT_NAME cond_pkg NAMESPACE CondPkg:: INCLUDE_SOURCES EXCLUSIVE)\n")
file(
  WRITE
  "${_conditional_include_dir}/include/cond_pkg/cond.hpp"
  "#pragma once\n"
  "int cond_value();\n")
file(
  WRITE
  "${_conditional_include_dir}/private/private.hpp"
  "#pragma once\n"
  "inline int private_value(){return 17;}\n")
file(
  WRITE
  "${_conditional_include_dir}/src/cond.cpp"
  "#include \"cond_pkg/cond.hpp\"\n"
  "#include \"private.hpp\"\n"
  "int cond_value(){return private_value();}\n")

set(_conditional_include_configure_command "${CMAKE_COMMAND}" -S "${_conditional_include_dir}" -B "${_conditional_include_build_dir}"
                                           "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _conditional_include_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _conditional_include_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _conditional_include_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _conditional_include_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _conditional_include_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _conditional_include_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _conditional_include_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-conditional-include" COMMAND ${_conditional_include_configure_command})
_tip_run_step(NAME "build-conditional-include" COMMAND "${CMAKE_COMMAND}" --build "${_conditional_include_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-conditional-include"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_conditional_include_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_conditional_include_install_prefix}")

set(_conditional_include_cache_file "${_conditional_include_build_dir}/CMakeCache.txt")
_tip_assert_exists("${_conditional_include_cache_file}")
_tip_read_cache_entry("${_conditional_include_cache_file}" "CMAKE_INSTALL_INCLUDEDIR" _conditional_install_includedir)
if(_conditional_install_includedir STREQUAL "")
  set(_conditional_install_includedir "include")
endif()
_tip_read_cache_entry("${_conditional_include_cache_file}" "CMAKE_INSTALL_DATADIR" _conditional_install_datadir)
if(_conditional_install_datadir STREQUAL "")
  set(_conditional_install_datadir "share")
endif()

set(_conditional_source_targets_file "${_conditional_include_install_prefix}/share/cmake/cond_pkg/cond_pkgSourceTargets.cmake")
_tip_assert_exists("${_conditional_source_targets_file}")
_tip_assert_file_not_contains("${_conditional_source_targets_file}" "${_conditional_include_dir}/private")
set(_conditional_installed_private_header "${_conditional_include_install_prefix}/${_conditional_install_datadir}/cond_pkg/cond/private.hpp")
_tip_assert_exists("${_conditional_installed_private_header}")
if(EXISTS "${_conditional_include_install_prefix}/${_conditional_install_includedir}/private.hpp")
  _tip_fail("Did not expect private header file set to install into the public include tree")
endif()

file(REMOVE_RECURSE "${_conditional_include_dir}/include" "${_conditional_include_dir}/private" "${_conditional_include_dir}/src")

set(_conditional_include_consumer_dir "${_conditional_include_dir}/consumer")
set(_conditional_include_consumer_build_dir "${_conditional_include_consumer_dir}/build")
file(MAKE_DIRECTORY "${_conditional_include_consumer_dir}")

file(
  WRITE
  "${_conditional_include_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_conditional_include_consumer LANGUAGES CXX)

find_package(cond_pkg CONFIG REQUIRED)
find_package(cond_pkg CONFIG REQUIRED)

get_target_property(_cond_local_target CondPkg::cond ALIASED_TARGET)
if(NOT _cond_local_target)
  message(FATAL_ERROR "CondPkg::cond is not an alias target")
endif()
get_target_property(_cond_private_includes "${_cond_local_target}" INCLUDE_DIRECTORIES)
get_target_property(_cond_interface_includes "${_cond_local_target}" INTERFACE_INCLUDE_DIRECTORIES)
get_target_property(_cond_sources "${_cond_local_target}" SOURCES)
set(_cond_cond_cpp_count 0)
foreach(_cond_source IN LISTS _cond_sources)
  if(_cond_source MATCHES "cond\\.cpp$")
    math(EXPR _cond_cond_cpp_count "${_cond_cond_cpp_count} + 1")
  endif()
endforeach()
file(WRITE "${CMAKE_BINARY_DIR}/cond_private_includes.txt" "${_cond_private_includes}\n")
file(WRITE "${CMAKE_BINARY_DIR}/cond_interface_includes.txt" "${_cond_interface_includes}\n")
file(WRITE "${CMAKE_BINARY_DIR}/cond_source_count.txt" "${_cond_cond_cpp_count}\n")

add_executable(conditional_include_consumer main.cpp)
target_link_libraries(conditional_include_consumer PRIVATE CondPkg::cond)
]=])

file(
  WRITE
  "${_conditional_include_consumer_dir}/main.cpp"
  [=[
#include "cond_pkg/cond.hpp"

int main() {
  return cond_value() == 17 ? 0 : 1;
}
]=])

set(_conditional_include_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_conditional_include_consumer_dir}"
    -B
    "${_conditional_include_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_conditional_include_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _conditional_include_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _conditional_include_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _conditional_include_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _conditional_include_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _conditional_include_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _conditional_include_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _conditional_include_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-conditional-include-consumer" COMMAND ${_conditional_include_consumer_configure_command})
_tip_run_step(
  NAME
  "build-conditional-include-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_conditional_include_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

_tip_assert_file_contains("${_conditional_include_consumer_build_dir}/cond_private_includes.txt"
                          "${_conditional_include_install_prefix}/${_conditional_install_datadir}/cond_pkg/cond")
_tip_assert_file_not_contains("${_conditional_include_consumer_build_dir}/cond_private_includes.txt" "${_conditional_include_dir}/private")
_tip_assert_file_contains("${_conditional_include_consumer_build_dir}/cond_interface_includes.txt"
                          "${_conditional_include_install_prefix}/${_conditional_install_includedir}")
_tip_assert_file_not_contains("${_conditional_include_consumer_build_dir}/cond_interface_includes.txt"
                              "${_conditional_include_install_prefix}/${_conditional_install_datadir}/cond_pkg/cond")
_tip_assert_file_contains("${_conditional_include_consumer_build_dir}/cond_source_count.txt" "1")

set(_conditional_include_consumer_executable_candidates
    "${_conditional_include_consumer_build_dir}/conditional_include_consumer${_tip_executable_suffix}"
    "${_conditional_include_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/conditional_include_consumer${_tip_executable_suffix}"
    "${_conditional_include_consumer_build_dir}/conditional_include_consumer"
    "${_conditional_include_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/conditional_include_consumer")
_tip_find_existing_path(_conditional_include_consumer_executable ${_conditional_include_consumer_executable_candidates})
_tip_run_step(NAME "run-conditional-include-consumer" COMMAND "${_conditional_include_consumer_executable}")

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
  set(_extensions_default_dir "${_case_root}/extensions-default")
  set(_extensions_default_build_dir "${_extensions_default_dir}/build")
  set(_extensions_default_install_prefix "${_extensions_default_dir}/install")
  file(MAKE_DIRECTORY "${_extensions_default_dir}/include/ext_pkg" "${_extensions_default_dir}/src")

  file(
    WRITE
    "${_extensions_default_dir}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 3.25)\n"
    "project(source_package_extensions_default LANGUAGES CXX)\n"
    "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
    "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
    "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
    "add_library(gnu_ext STATIC src/gnu_ext.cpp)\n"
    "target_sources(gnu_ext PUBLIC FILE_SET HEADERS BASE_DIRS \"${_extensions_default_dir}/include\" FILES \"include/ext_pkg/gnu_ext.hpp\")\n"
    "target_compile_features(gnu_ext PUBLIC cxx_std_17)\n"
    "target_install_package(gnu_ext EXPORT_NAME ext_pkg NAMESPACE ExtPkg:: INCLUDE_SOURCES EXCLUSIVE)\n")
  file(
    WRITE
    "${_extensions_default_dir}/include/ext_pkg/gnu_ext.hpp"
    "#pragma once\n"
    "int gnu_ext_value();\n")
  file(
    WRITE
    "${_extensions_default_dir}/src/gnu_ext.cpp"
    "#include \"ext_pkg/gnu_ext.hpp\"\n"
    "int gnu_ext_value(){ return ({ int value = 29; value; }); }\n")

  set(_extensions_default_configure_command "${CMAKE_COMMAND}" -S "${_extensions_default_dir}" -B "${_extensions_default_build_dir}"
                                            "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
  if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
    list(APPEND _extensions_default_configure_command -G "${TIP_CMAKE_GENERATOR}")
  endif()
  if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
    list(APPEND _extensions_default_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
  endif()
  if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
    list(APPEND _extensions_default_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
  endif()
  if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
    list(APPEND _extensions_default_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
  endif()
  if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
    list(APPEND _extensions_default_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
  endif()
  if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
    list(APPEND _extensions_default_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
  endif()
  if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
    list(APPEND _extensions_default_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
  endif()

  _tip_run_step(NAME "configure-extensions-default" COMMAND ${_extensions_default_configure_command})
  _tip_run_step(NAME "build-extensions-default" COMMAND "${CMAKE_COMMAND}" --build "${_extensions_default_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
  _tip_run_step(
    NAME
    "install-extensions-default"
    COMMAND
    "${CMAKE_COMMAND}"
    --install
    "${_extensions_default_build_dir}"
    --config
    "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
    --prefix
    "${_extensions_default_install_prefix}")

  set(_extensions_default_consumer_dir "${_extensions_default_dir}/consumer")
  set(_extensions_default_consumer_build_dir "${_extensions_default_consumer_dir}/build")
  file(MAKE_DIRECTORY "${_extensions_default_consumer_dir}")

  file(
    WRITE
    "${_extensions_default_consumer_dir}/CMakeLists.txt"
    [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_extensions_default_consumer LANGUAGES CXX)

find_package(ext_pkg CONFIG REQUIRED)

add_executable(extensions_default_consumer main.cpp)
target_link_libraries(extensions_default_consumer PRIVATE ExtPkg::gnu_ext)
]=])

  file(
    WRITE
    "${_extensions_default_consumer_dir}/main.cpp"
    [=[
#include "ext_pkg/gnu_ext.hpp"

int main() {
  return gnu_ext_value() == 29 ? 0 : 1;
}
]=])

  set(_extensions_default_consumer_configure_command
      "${CMAKE_COMMAND}"
      -S
      "${_extensions_default_consumer_dir}"
      -B
      "${_extensions_default_consumer_build_dir}"
      "-DCMAKE_PREFIX_PATH=${_extensions_default_install_prefix}"
      "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
  if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
    list(APPEND _extensions_default_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
  endif()
  if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
    list(APPEND _extensions_default_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
  endif()
  if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
    list(APPEND _extensions_default_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
  endif()
  if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
    list(APPEND _extensions_default_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
  endif()
  if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
    list(APPEND _extensions_default_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
  endif()
  if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
    list(APPEND _extensions_default_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
  endif()
  if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
    list(APPEND _extensions_default_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
  endif()

  _tip_run_step(NAME "configure-extensions-default-consumer" COMMAND ${_extensions_default_consumer_configure_command})
  _tip_run_step(
    NAME
    "build-extensions-default-consumer"
    COMMAND
    "${CMAKE_COMMAND}"
    --build
    "${_extensions_default_consumer_build_dir}"
    --config
    "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

  set(_extensions_default_consumer_executable_candidates
      "${_extensions_default_consumer_build_dir}/extensions_default_consumer${_tip_executable_suffix}"
      "${_extensions_default_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/extensions_default_consumer${_tip_executable_suffix}"
      "${_extensions_default_consumer_build_dir}/extensions_default_consumer"
      "${_extensions_default_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/extensions_default_consumer")
  _tip_find_existing_path(_extensions_default_consumer_executable ${_extensions_default_consumer_executable_candidates})
  _tip_run_step(NAME "run-extensions-default-consumer" COMMAND "${_extensions_default_consumer_executable}")
endif()

set(_interface_scope_dir "${_case_root}/interface-scope")
set(_interface_scope_build_dir "${_interface_scope_dir}/build")
set(_interface_scope_install_prefix "${_interface_scope_dir}/install")
file(MAKE_DIRECTORY "${_interface_scope_dir}/include/iface_scope" "${_interface_scope_dir}/src")

file(
  WRITE
  "${_interface_scope_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_interface_scope LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(iface_scope STATIC src/iface_scope.cpp)\n"
  "target_sources(iface_scope PUBLIC FILE_SET HEADERS BASE_DIRS \"${_interface_scope_dir}/include\" FILES \"include/iface_scope/iface_scope.hpp\")\n"
  "target_compile_definitions(iface_scope INTERFACE BAD_INTERFACE_DEF=1)\n"
  "target_install_package(iface_scope EXPORT_NAME iface_scope_pkg NAMESPACE IfaceScope:: INCLUDE_SOURCES EXCLUSIVE)\n")
file(
  WRITE
  "${_interface_scope_dir}/include/iface_scope/iface_scope.hpp"
  "#pragma once\n"
  "int iface_scope_value();\n")
file(
  WRITE
  "${_interface_scope_dir}/src/iface_scope.cpp"
  "#ifdef BAD_INTERFACE_DEF\n"
  "#error BAD_INTERFACE_DEF must not be visible while compiling iface_scope itself\n"
  "#endif\n"
  "#include \"iface_scope/iface_scope.hpp\"\n"
  "int iface_scope_value(){return 31;}\n")

set(_interface_scope_configure_command "${CMAKE_COMMAND}" -S "${_interface_scope_dir}" -B "${_interface_scope_build_dir}"
                                       "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _interface_scope_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _interface_scope_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _interface_scope_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _interface_scope_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _interface_scope_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _interface_scope_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _interface_scope_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-interface-scope" COMMAND ${_interface_scope_configure_command})
_tip_run_step(NAME "build-interface-scope" COMMAND "${CMAKE_COMMAND}" --build "${_interface_scope_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-interface-scope"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_interface_scope_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_interface_scope_install_prefix}")

set(_interface_scope_consumer_dir "${_interface_scope_dir}/consumer")
set(_interface_scope_consumer_build_dir "${_interface_scope_consumer_dir}/build")
file(MAKE_DIRECTORY "${_interface_scope_consumer_dir}")

file(
  WRITE
  "${_interface_scope_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_interface_scope_consumer LANGUAGES CXX)

find_package(iface_scope_pkg CONFIG REQUIRED)

add_executable(interface_scope_consumer main.cpp)
target_link_libraries(interface_scope_consumer PRIVATE IfaceScope::iface_scope)
]=])

file(
  WRITE
  "${_interface_scope_consumer_dir}/main.cpp"
  [=[
#include "iface_scope/iface_scope.hpp"

int main() {
  return iface_scope_value() == 31 ? 0 : 1;
}
]=])

set(_interface_scope_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_interface_scope_consumer_dir}"
    -B
    "${_interface_scope_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_interface_scope_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _interface_scope_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _interface_scope_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _interface_scope_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _interface_scope_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _interface_scope_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _interface_scope_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _interface_scope_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-interface-scope-consumer" COMMAND ${_interface_scope_consumer_configure_command})
_tip_run_step(
  NAME
  "build-interface-scope-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_interface_scope_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

set(_interface_scope_consumer_executable_candidates
    "${_interface_scope_consumer_build_dir}/interface_scope_consumer${_tip_executable_suffix}"
    "${_interface_scope_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/interface_scope_consumer${_tip_executable_suffix}"
    "${_interface_scope_consumer_build_dir}/interface_scope_consumer"
    "${_interface_scope_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/interface_scope_consumer")
_tip_find_existing_path(_interface_scope_consumer_executable ${_interface_scope_consumer_executable_candidates})
_tip_run_step(NAME "run-interface-scope-consumer" COMMAND "${_interface_scope_consumer_executable}")

set(_cxx_standard_dir "${_case_root}/cxx-standard")
set(_cxx_standard_build_dir "${_cxx_standard_dir}/build")
set(_cxx_standard_install_prefix "${_cxx_standard_dir}/install")
file(MAKE_DIRECTORY "${_cxx_standard_dir}/include/std_pkg" "${_cxx_standard_dir}/src")

file(
  WRITE
  "${_cxx_standard_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_cxx_standard LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(cxx_standard STATIC src/cxx_standard.cpp)\n"
  "target_sources(cxx_standard PUBLIC FILE_SET HEADERS BASE_DIRS \"${_cxx_standard_dir}/include\" FILES \"include/std_pkg/cxx_standard.hpp\")\n"
  "set_target_properties(cxx_standard PROPERTIES CXX_STANDARD 20 CXX_STANDARD_REQUIRED ON)\n"
  "target_install_package(cxx_standard EXPORT_NAME std_pkg NAMESPACE StdPkg:: INCLUDE_SOURCES EXCLUSIVE)\n")
file(
  WRITE
  "${_cxx_standard_dir}/include/std_pkg/cxx_standard.hpp"
  "#pragma once\n"
  "int cxx_standard_value();\n")
file(
  WRITE
  "${_cxx_standard_dir}/src/cxx_standard.cpp"
  "#include \"std_pkg/cxx_standard.hpp\"\n"
  "#include <span>\n"
  "#include <array>\n"
  "int cxx_standard_value(){ std::array<int, 3> values{2, 3, 4}; std::span<const int> view(values); return view[0] + view[1] + view[2]; }\n")

set(_cxx_standard_configure_command "${CMAKE_COMMAND}" -S "${_cxx_standard_dir}" -B "${_cxx_standard_build_dir}"
                                    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _cxx_standard_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _cxx_standard_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _cxx_standard_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _cxx_standard_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _cxx_standard_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _cxx_standard_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _cxx_standard_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-cxx-standard" COMMAND ${_cxx_standard_configure_command})
_tip_run_step(NAME "build-cxx-standard" COMMAND "${CMAKE_COMMAND}" --build "${_cxx_standard_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-cxx-standard"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_cxx_standard_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_cxx_standard_install_prefix}")

set(_cxx_standard_consumer_dir "${_cxx_standard_dir}/consumer")
set(_cxx_standard_consumer_build_dir "${_cxx_standard_consumer_dir}/build")
file(MAKE_DIRECTORY "${_cxx_standard_consumer_dir}")

file(
  WRITE
  "${_cxx_standard_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_cxx_standard_consumer LANGUAGES CXX)

find_package(std_pkg CONFIG REQUIRED)

get_target_property(_std_local_target StdPkg::cxx_standard ALIASED_TARGET)
if(NOT _std_local_target)
  message(FATAL_ERROR "StdPkg::cxx_standard is not an alias target")
endif()
get_target_property(_std_cxx_standard "${_std_local_target}" CXX_STANDARD)
get_target_property(_std_cxx_standard_required "${_std_local_target}" CXX_STANDARD_REQUIRED)
file(WRITE "${CMAKE_BINARY_DIR}/std_cxx_standard.txt" "${_std_cxx_standard}\n")
file(WRITE "${CMAKE_BINARY_DIR}/std_cxx_standard_required.txt" "${_std_cxx_standard_required}\n")

add_executable(cxx_standard_consumer main.cpp)
target_link_libraries(cxx_standard_consumer PRIVATE StdPkg::cxx_standard)
]=])

file(
  WRITE
  "${_cxx_standard_consumer_dir}/main.cpp"
  [=[
#include "std_pkg/cxx_standard.hpp"

int main() {
  return cxx_standard_value() == 9 ? 0 : 1;
}
]=])

set(_cxx_standard_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_cxx_standard_consumer_dir}"
    -B
    "${_cxx_standard_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_cxx_standard_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _cxx_standard_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _cxx_standard_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _cxx_standard_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _cxx_standard_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _cxx_standard_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _cxx_standard_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _cxx_standard_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-cxx-standard-consumer" COMMAND ${_cxx_standard_consumer_configure_command})
_tip_run_step(
  NAME
  "build-cxx-standard-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_cxx_standard_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

_tip_assert_file_contains("${_cxx_standard_consumer_build_dir}/std_cxx_standard.txt" "20")
_tip_assert_file_contains("${_cxx_standard_consumer_build_dir}/std_cxx_standard_required.txt" "ON")

set(_cxx_standard_consumer_executable_candidates
    "${_cxx_standard_consumer_build_dir}/cxx_standard_consumer${_tip_executable_suffix}"
    "${_cxx_standard_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/cxx_standard_consumer${_tip_executable_suffix}"
    "${_cxx_standard_consumer_build_dir}/cxx_standard_consumer"
    "${_cxx_standard_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/cxx_standard_consumer")
_tip_find_existing_path(_cxx_standard_consumer_executable ${_cxx_standard_consumer_executable_candidates})
_tip_run_step(NAME "run-cxx-standard-consumer" COMMAND "${_cxx_standard_consumer_executable}")

set(_c_standard_dir "${_case_root}/c-standard")
set(_c_standard_build_dir "${_c_standard_dir}/build")
set(_c_standard_install_prefix "${_c_standard_dir}/install")
file(MAKE_DIRECTORY "${_c_standard_dir}/include/c_std_pkg" "${_c_standard_dir}/src")

file(
  WRITE
  "${_c_standard_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_c_standard LANGUAGES C)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(c_standard STATIC src/c_standard.c)\n"
  "target_sources(c_standard PUBLIC FILE_SET HEADERS BASE_DIRS \"${_c_standard_dir}/include\" FILES \"include/c_std_pkg/c_standard.h\")\n"
  "set_target_properties(c_standard PROPERTIES C_STANDARD 11 C_STANDARD_REQUIRED ON C_EXTENSIONS OFF)\n"
  "target_install_package(c_standard EXPORT_NAME c_std_pkg NAMESPACE CStdPkg:: INCLUDE_SOURCES EXCLUSIVE)\n")
file(
  WRITE
  "${_c_standard_dir}/include/c_std_pkg/c_standard.h"
  "#pragma once\n"
  "int c_standard_value(void);\n")
file(
  WRITE
  "${_c_standard_dir}/src/c_standard.c"
  "#include \"c_std_pkg/c_standard.h\"\n"
  "int c_standard_value(void) { return 12; }\n")

set(_c_standard_configure_command "${CMAKE_COMMAND}" -S "${_c_standard_dir}" -B "${_c_standard_build_dir}"
                                  "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _c_standard_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _c_standard_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _c_standard_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _c_standard_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _c_standard_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _c_standard_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _c_standard_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-c-standard" COMMAND ${_c_standard_configure_command})
_tip_run_step(NAME "build-c-standard" COMMAND "${CMAKE_COMMAND}" --build "${_c_standard_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-c-standard"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_c_standard_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_c_standard_install_prefix}")

set(_c_standard_consumer_dir "${_c_standard_dir}/consumer")
set(_c_standard_consumer_build_dir "${_c_standard_consumer_dir}/build")
file(MAKE_DIRECTORY "${_c_standard_consumer_dir}")

file(
  WRITE
  "${_c_standard_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_c_standard_consumer LANGUAGES C)

find_package(c_std_pkg CONFIG REQUIRED)

get_target_property(_c_std_local_target CStdPkg::c_standard ALIASED_TARGET)
if(NOT _c_std_local_target)
  message(FATAL_ERROR "CStdPkg::c_standard is not an alias target")
endif()
get_target_property(_c_std_standard "${_c_std_local_target}" C_STANDARD)
get_target_property(_c_std_standard_required "${_c_std_local_target}" C_STANDARD_REQUIRED)
get_target_property(_c_std_extensions "${_c_std_local_target}" C_EXTENSIONS)
file(WRITE "${CMAKE_BINARY_DIR}/std_c_standard.txt" "${_c_std_standard}\n")
file(WRITE "${CMAKE_BINARY_DIR}/std_c_standard_required.txt" "${_c_std_standard_required}\n")
file(WRITE "${CMAKE_BINARY_DIR}/std_c_extensions.txt" "${_c_std_extensions}\n")

add_executable(c_standard_consumer main.c)
target_link_libraries(c_standard_consumer PRIVATE CStdPkg::c_standard)
]=])

file(
  WRITE
  "${_c_standard_consumer_dir}/main.c"
  [=[
#include "c_std_pkg/c_standard.h"

int main(void) {
  return c_standard_value() == 12 ? 0 : 1;
}
]=])

set(_c_standard_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_c_standard_consumer_dir}"
    -B
    "${_c_standard_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_c_standard_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _c_standard_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _c_standard_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _c_standard_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _c_standard_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _c_standard_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _c_standard_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _c_standard_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-c-standard-consumer" COMMAND ${_c_standard_consumer_configure_command})
_tip_run_step(
  NAME
  "build-c-standard-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_c_standard_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

_tip_assert_file_contains("${_c_standard_consumer_build_dir}/std_c_standard.txt" "11")
_tip_assert_file_contains("${_c_standard_consumer_build_dir}/std_c_standard_required.txt" "ON")
_tip_assert_file_contains("${_c_standard_consumer_build_dir}/std_c_extensions.txt" "OFF")

set(_c_standard_consumer_executable_candidates
    "${_c_standard_consumer_build_dir}/c_standard_consumer${_tip_executable_suffix}"
    "${_c_standard_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/c_standard_consumer${_tip_executable_suffix}"
    "${_c_standard_consumer_build_dir}/c_standard_consumer"
    "${_c_standard_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/c_standard_consumer")
_tip_find_existing_path(_c_standard_consumer_executable ${_c_standard_consumer_executable_candidates})
_tip_run_step(NAME "run-c-standard-consumer" COMMAND "${_c_standard_consumer_executable}")

set(_usage_norm_dir "${_case_root}/usage-normalization")
set(_usage_norm_build_dir "${_usage_norm_dir}/build")
set(_usage_norm_install_prefix "${_usage_norm_dir}/install")
file(MAKE_DIRECTORY "${_usage_norm_dir}/build-only-include" "${_usage_norm_dir}/include/usage_norm_pkg" "${_usage_norm_dir}/include/usage_norm_pkg/direct_install"
     "${_usage_norm_dir}/include/usage_norm_pkg/nested" "${_usage_norm_dir}/src")

file(
  WRITE
  "${_usage_norm_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_usage_normalization LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(usage_norm STATIC src/usage_norm.cpp)\n"
  "target_sources(usage_norm PUBLIC FILE_SET HEADERS BASE_DIRS \"${_usage_norm_dir}/include\" FILES "
  "\"include/usage_norm_pkg/usage_norm.hpp\" \"include/usage_norm_pkg/nested/nested_marker.hpp\")\n"
  "target_compile_definitions(usage_norm PUBLIC \"$<BUILD_INTERFACE:USAGE_NORM_DEF=1>\" \"$<INSTALL_INTERFACE:USAGE_NORM_DEF=2>\")\n"
  "target_compile_definitions(usage_norm PUBLIC \"$<$<BOOL:1>:$<BUILD_INTERFACE:USAGE_NORM_NESTED_DEF=1>>\" "
  "\"$<$<BOOL:1>:$<INSTALL_INTERFACE:USAGE_NORM_NESTED_DEF=2>>\")\n"
  "target_compile_options(usage_norm PUBLIC\n"
  "  \"$<BUILD_INTERFACE:$<$<CXX_COMPILER_ID:MSVC>:/DUSAGE_NORM_OPT=3>>\"\n"
  "  \"$<BUILD_INTERFACE:$<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-DUSAGE_NORM_OPT=3>>\"\n"
  "  \"$<INSTALL_INTERFACE:$<$<CXX_COMPILER_ID:MSVC>:/DUSAGE_NORM_OPT=4>>\"\n"
  "  \"$<INSTALL_INTERFACE:$<$<NOT:$<CXX_COMPILER_ID:MSVC>>:-DUSAGE_NORM_OPT=4>>\")\n"
  "target_include_directories(usage_norm PUBLIC \"$<$<BOOL:1>:$<BUILD_INTERFACE:${_usage_norm_dir}/build-only-include>>\" "
  "\"$<$<BOOL:1>:$<INSTALL_INTERFACE:include/usage_norm_pkg/nested>>\" "
  "\"$<INSTALL_INTERFACE:$<$<BOOL:1>:include/usage_norm_pkg/direct_install>>\")\n"
  "target_install_package(usage_norm EXPORT_NAME usage_norm_pkg NAMESPACE UsageNormPkg:: INCLUDE_SOURCES EXCLUSIVE)\n")
file(
  WRITE
  "${_usage_norm_dir}/include/usage_norm_pkg/usage_norm.hpp"
  "#pragma once\n"
  "int usage_norm_value();\n")
file(
  WRITE
  "${_usage_norm_dir}/build-only-include/nested_marker.hpp"
  "#pragma once\n"
  "#define USAGE_NORM_NESTED_MARKER 1\n")
file(
  WRITE
  "${_usage_norm_dir}/include/usage_norm_pkg/direct_install/direct_install_marker.hpp"
  "#pragma once\n"
  "#define USAGE_NORM_DIRECT_INSTALL_MARKER 1\n")
file(
  WRITE
  "${_usage_norm_dir}/include/usage_norm_pkg/nested/nested_marker.hpp"
  "#pragma once\n"
  "#define USAGE_NORM_NESTED_MARKER 1\n")
file(
  WRITE
  "${_usage_norm_dir}/src/usage_norm.cpp"
  "#include \"usage_norm_pkg/usage_norm.hpp\"\n"
  "#include \"nested_marker.hpp\"\n"
  "#ifndef USAGE_NORM_DEF\n"
  "#error USAGE_NORM_DEF missing\n"
  "#endif\n"
  "#ifndef USAGE_NORM_NESTED_DEF\n"
  "#error USAGE_NORM_NESTED_DEF missing\n"
  "#endif\n"
  "#ifndef USAGE_NORM_OPT\n"
  "#error USAGE_NORM_OPT missing\n"
  "#endif\n"
  "#ifndef USAGE_NORM_NESTED_MARKER\n"
  "#error nested include directory missing\n"
  "#endif\n"
  "int usage_norm_value(){return (USAGE_NORM_DEF * 10) + USAGE_NORM_OPT + USAGE_NORM_NESTED_DEF;}\n")

set(_usage_norm_configure_command "${CMAKE_COMMAND}" -S "${_usage_norm_dir}" -B "${_usage_norm_build_dir}"
                                  "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _usage_norm_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _usage_norm_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _usage_norm_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _usage_norm_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _usage_norm_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _usage_norm_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _usage_norm_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-usage-normalization" COMMAND ${_usage_norm_configure_command})
_tip_run_step(NAME "build-usage-normalization" COMMAND "${CMAKE_COMMAND}" --build "${_usage_norm_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-usage-normalization"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_usage_norm_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_usage_norm_install_prefix}")

set(_usage_norm_consumer_dir "${_usage_norm_dir}/consumer")
set(_usage_norm_consumer_build_dir "${_usage_norm_consumer_dir}/build")
file(MAKE_DIRECTORY "${_usage_norm_consumer_dir}")

file(
  WRITE
  "${_usage_norm_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_usage_normalization_consumer LANGUAGES CXX)

find_package(usage_norm_pkg CONFIG REQUIRED)

get_target_property(_usage_norm_local_target UsageNormPkg::usage_norm ALIASED_TARGET)
if(NOT _usage_norm_local_target)
  message(FATAL_ERROR "UsageNormPkg::usage_norm is not an alias target")
endif()
get_target_property(_usage_norm_defs "${_usage_norm_local_target}" COMPILE_DEFINITIONS)
get_target_property(_usage_norm_iface_defs "${_usage_norm_local_target}" INTERFACE_COMPILE_DEFINITIONS)
get_target_property(_usage_norm_opts "${_usage_norm_local_target}" COMPILE_OPTIONS)
get_target_property(_usage_norm_iface_opts "${_usage_norm_local_target}" INTERFACE_COMPILE_OPTIONS)
get_target_property(_usage_norm_includes "${_usage_norm_local_target}" INCLUDE_DIRECTORIES)
get_target_property(_usage_norm_iface_includes "${_usage_norm_local_target}" INTERFACE_INCLUDE_DIRECTORIES)
file(WRITE "${CMAKE_BINARY_DIR}/usage_norm_defs.txt" "${_usage_norm_defs}\n")
file(WRITE "${CMAKE_BINARY_DIR}/usage_norm_iface_defs.txt" "${_usage_norm_iface_defs}\n")
file(WRITE "${CMAKE_BINARY_DIR}/usage_norm_opts.txt" "${_usage_norm_opts}\n")
file(WRITE "${CMAKE_BINARY_DIR}/usage_norm_iface_opts.txt" "${_usage_norm_iface_opts}\n")
file(WRITE "${CMAKE_BINARY_DIR}/usage_norm_includes.txt" "${_usage_norm_includes}\n")
file(WRITE "${CMAKE_BINARY_DIR}/usage_norm_iface_includes.txt" "${_usage_norm_iface_includes}\n")

add_executable(usage_norm_consumer main.cpp)
target_link_libraries(usage_norm_consumer PRIVATE UsageNormPkg::usage_norm)
]=])

file(
  WRITE
  "${_usage_norm_consumer_dir}/main.cpp"
  [=[
#include "usage_norm_pkg/usage_norm.hpp"

int main() {
  return usage_norm_value() == 26 ? 0 : 1;
}
]=])

set(_usage_norm_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_usage_norm_consumer_dir}"
    -B
    "${_usage_norm_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_usage_norm_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _usage_norm_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _usage_norm_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _usage_norm_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _usage_norm_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _usage_norm_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _usage_norm_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _usage_norm_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-usage-normalization-consumer" COMMAND ${_usage_norm_consumer_configure_command})
_tip_run_step(
  NAME
  "build-usage-normalization-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_usage_norm_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

_tip_assert_file_contains("${_usage_norm_consumer_build_dir}/usage_norm_defs.txt" "USAGE_NORM_DEF=2")
_tip_assert_file_contains("${_usage_norm_consumer_build_dir}/usage_norm_defs.txt" "USAGE_NORM_NESTED_DEF=2")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_defs.txt" "USAGE_NORM_DEF=1")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_defs.txt" "USAGE_NORM_NESTED_DEF=1")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_defs.txt" "BUILD_INTERFACE")
_tip_assert_file_contains("${_usage_norm_consumer_build_dir}/usage_norm_iface_defs.txt" "USAGE_NORM_DEF=2")
_tip_assert_file_contains("${_usage_norm_consumer_build_dir}/usage_norm_iface_defs.txt" "USAGE_NORM_NESTED_DEF=2")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_iface_defs.txt" "USAGE_NORM_DEF=1")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_iface_defs.txt" "USAGE_NORM_NESTED_DEF=1")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_iface_defs.txt" "BUILD_INTERFACE")
_tip_assert_file_contains("${_usage_norm_consumer_build_dir}/usage_norm_opts.txt" "USAGE_NORM_OPT=4")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_opts.txt" "USAGE_NORM_OPT=3")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_opts.txt" "BUILD_INTERFACE")
_tip_assert_file_contains("${_usage_norm_consumer_build_dir}/usage_norm_iface_opts.txt" "USAGE_NORM_OPT=4")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_iface_opts.txt" "USAGE_NORM_OPT=3")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_iface_opts.txt" "BUILD_INTERFACE")
_tip_assert_file_contains("${_usage_norm_consumer_build_dir}/usage_norm_includes.txt" "${_usage_norm_install_prefix}/include/usage_norm_pkg/nested")
_tip_assert_file_contains("${_usage_norm_consumer_build_dir}/usage_norm_includes.txt" "${_usage_norm_install_prefix}/include/usage_norm_pkg/direct_install")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_includes.txt" "${_usage_norm_dir}/build-only-include")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_includes.txt" "$<$<BOOL:1>:include/usage_norm_pkg/direct_install>")
_tip_assert_file_contains("${_usage_norm_consumer_build_dir}/usage_norm_iface_includes.txt" "${_usage_norm_install_prefix}/include/usage_norm_pkg/nested")
_tip_assert_file_contains("${_usage_norm_consumer_build_dir}/usage_norm_iface_includes.txt" "${_usage_norm_install_prefix}/include/usage_norm_pkg/direct_install")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_iface_includes.txt" "${_usage_norm_dir}/build-only-include")
_tip_assert_file_not_contains("${_usage_norm_consumer_build_dir}/usage_norm_iface_includes.txt" "$<$<BOOL:1>:include/usage_norm_pkg/direct_install>")

set(_usage_norm_consumer_executable_candidates
    "${_usage_norm_consumer_build_dir}/usage_norm_consumer${_tip_executable_suffix}"
    "${_usage_norm_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/usage_norm_consumer${_tip_executable_suffix}"
    "${_usage_norm_consumer_build_dir}/usage_norm_consumer"
    "${_usage_norm_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/usage_norm_consumer")
_tip_find_existing_path(_usage_norm_consumer_executable ${_usage_norm_consumer_executable_candidates})
_tip_run_step(NAME "run-usage-normalization-consumer" COMMAND "${_usage_norm_consumer_executable}")

set(_usage_norm_list_dir "${_case_root}/usage-normalization-list-payloads")
set(_usage_norm_list_build_dir "${_usage_norm_list_dir}/build")
set(_usage_norm_list_install_prefix "${_usage_norm_list_dir}/install")
file(
  MAKE_DIRECTORY
  "${_usage_norm_list_dir}/build-only-include/a"
  "${_usage_norm_list_dir}/build-only-include/b"
  "${_usage_norm_list_dir}/include/usage_norm_list_pkg"
  "${_usage_norm_list_dir}/include/usage_norm_list_pkg/install_a"
  "${_usage_norm_list_dir}/include/usage_norm_list_pkg/install_b"
  "${_usage_norm_list_dir}/src")

file(
  WRITE
  "${_usage_norm_list_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_usage_normalization_list_payloads LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(usage_norm_list STATIC src/usage_norm_list.cpp)\n"
  "target_sources(usage_norm_list PUBLIC FILE_SET HEADERS BASE_DIRS \"${_usage_norm_list_dir}/include\" FILES "
  "\"include/usage_norm_list_pkg/usage_norm_list.hpp\" "
  "\"include/usage_norm_list_pkg/install_a/install_list_marker_a.hpp\" "
  "\"include/usage_norm_list_pkg/install_b/install_list_marker_b.hpp\")\n"
  "target_compile_definitions(usage_norm_list PUBLIC\n"
  "  \"$<$<BOOL:1>:$<BUILD_INTERFACE:USAGE_NORM_LIST_BUILD_A=1;USAGE_NORM_LIST_BUILD_B=2>>\"\n"
  "  \"$<$<BOOL:1>:$<INSTALL_INTERFACE:USAGE_NORM_LIST_INSTALL_A=3;USAGE_NORM_LIST_INSTALL_B=4>>\")\n"
  "target_include_directories(usage_norm_list PUBLIC\n"
  "  \"$<$<BOOL:1>:$<BUILD_INTERFACE:${_usage_norm_list_dir}/build-only-include/a;${_usage_norm_list_dir}/build-only-include/b>>\"\n"
  "  \"$<$<BOOL:1>:$<INSTALL_INTERFACE:include/usage_norm_list_pkg/install_a;include/usage_norm_list_pkg/install_b>>\")\n"
  "target_install_package(usage_norm_list EXPORT_NAME usage_norm_list_pkg NAMESPACE UsageNormListPkg:: INCLUDE_SOURCES EXCLUSIVE)\n")
file(
  WRITE
  "${_usage_norm_list_dir}/include/usage_norm_list_pkg/usage_norm_list.hpp"
  "#pragma once\n"
  "int usage_norm_list_value();\n")
file(
  WRITE
  "${_usage_norm_list_dir}/build-only-include/a/build_list_marker_a.hpp"
  "#pragma once\n"
  "#define BUILD_LIST_MARKER_A 1\n")
file(
  WRITE
  "${_usage_norm_list_dir}/build-only-include/b/build_list_marker_b.hpp"
  "#pragma once\n"
  "#define BUILD_LIST_MARKER_B 1\n")
file(
  WRITE
  "${_usage_norm_list_dir}/include/usage_norm_list_pkg/install_a/install_list_marker_a.hpp"
  "#pragma once\n"
  "#define INSTALL_LIST_MARKER_A 1\n")
file(
  WRITE
  "${_usage_norm_list_dir}/include/usage_norm_list_pkg/install_b/install_list_marker_b.hpp"
  "#pragma once\n"
  "#define INSTALL_LIST_MARKER_B 1\n")
file(
  WRITE
  "${_usage_norm_list_dir}/src/usage_norm_list.cpp"
  "#include \"usage_norm_list_pkg/usage_norm_list.hpp\"\n"
  "#if defined(USAGE_NORM_LIST_BUILD_A)\n"
  "#include \"build_list_marker_a.hpp\"\n"
  "#include \"build_list_marker_b.hpp\"\n"
  "#elif defined(USAGE_NORM_LIST_INSTALL_A)\n"
  "#include \"install_list_marker_a.hpp\"\n"
  "#include \"install_list_marker_b.hpp\"\n"
  "#else\n"
  "#error usage_norm_list macros missing\n"
  "#endif\n"
  "#if defined(USAGE_NORM_LIST_BUILD_A) && defined(USAGE_NORM_LIST_INSTALL_A)\n"
  "#error build macros leaked into install usage\n"
  "#endif\n"
  "int usage_norm_list_value(){\n"
  "#if defined(USAGE_NORM_LIST_BUILD_A)\n"
  "  return USAGE_NORM_LIST_BUILD_A + USAGE_NORM_LIST_BUILD_B + BUILD_LIST_MARKER_A + BUILD_LIST_MARKER_B;\n"
  "#else\n"
  "  return USAGE_NORM_LIST_INSTALL_A + USAGE_NORM_LIST_INSTALL_B + INSTALL_LIST_MARKER_A + INSTALL_LIST_MARKER_B;\n"
  "#endif\n"
  "}\n")

set(_usage_norm_list_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_usage_norm_list_dir}"
    -B
    "${_usage_norm_list_build_dir}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _usage_norm_list_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _usage_norm_list_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _usage_norm_list_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _usage_norm_list_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _usage_norm_list_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _usage_norm_list_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _usage_norm_list_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-usage-normalization-list-payloads" COMMAND ${_usage_norm_list_configure_command})
_tip_run_step(NAME "build-usage-normalization-list-payloads" COMMAND "${CMAKE_COMMAND}" --build "${_usage_norm_list_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-usage-normalization-list-payloads"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_usage_norm_list_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_usage_norm_list_install_prefix}")

set(_usage_norm_list_consumer_dir "${_usage_norm_list_dir}/consumer")
set(_usage_norm_list_consumer_build_dir "${_usage_norm_list_consumer_dir}/build")
file(MAKE_DIRECTORY "${_usage_norm_list_consumer_dir}")

file(
  WRITE
  "${_usage_norm_list_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_usage_normalization_list_payloads_consumer LANGUAGES CXX)

find_package(usage_norm_list_pkg CONFIG REQUIRED)

get_target_property(_usage_norm_list_local_target UsageNormListPkg::usage_norm_list ALIASED_TARGET)
if(NOT _usage_norm_list_local_target)
  message(FATAL_ERROR "UsageNormListPkg::usage_norm_list is not an alias target")
endif()
get_target_property(_usage_norm_list_defs "${_usage_norm_list_local_target}" COMPILE_DEFINITIONS)
get_target_property(_usage_norm_list_iface_defs "${_usage_norm_list_local_target}" INTERFACE_COMPILE_DEFINITIONS)
get_target_property(_usage_norm_list_includes "${_usage_norm_list_local_target}" INCLUDE_DIRECTORIES)
get_target_property(_usage_norm_list_iface_includes "${_usage_norm_list_local_target}" INTERFACE_INCLUDE_DIRECTORIES)
file(WRITE "${CMAKE_BINARY_DIR}/usage_norm_list_defs.txt" "${_usage_norm_list_defs}\n")
file(WRITE "${CMAKE_BINARY_DIR}/usage_norm_list_iface_defs.txt" "${_usage_norm_list_iface_defs}\n")
file(WRITE "${CMAKE_BINARY_DIR}/usage_norm_list_includes.txt" "${_usage_norm_list_includes}\n")
file(WRITE "${CMAKE_BINARY_DIR}/usage_norm_list_iface_includes.txt" "${_usage_norm_list_iface_includes}\n")

add_executable(usage_norm_list_consumer main.cpp)
target_link_libraries(usage_norm_list_consumer PRIVATE UsageNormListPkg::usage_norm_list)
]=])

file(
  WRITE
  "${_usage_norm_list_consumer_dir}/main.cpp"
  [=[
#include "usage_norm_list_pkg/usage_norm_list.hpp"

int main() {
  return usage_norm_list_value() == 9 ? 0 : 1;
}
]=])

set(_usage_norm_list_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_usage_norm_list_consumer_dir}"
    -B
    "${_usage_norm_list_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_usage_norm_list_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _usage_norm_list_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _usage_norm_list_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _usage_norm_list_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _usage_norm_list_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _usage_norm_list_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _usage_norm_list_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _usage_norm_list_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-usage-normalization-list-payloads-consumer" COMMAND ${_usage_norm_list_consumer_configure_command})
_tip_run_step(
  NAME
  "build-usage-normalization-list-payloads-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_usage_norm_list_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

_tip_assert_file_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_defs.txt" "USAGE_NORM_LIST_INSTALL_A=3")
_tip_assert_file_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_defs.txt" "USAGE_NORM_LIST_INSTALL_B=4")
_tip_assert_file_not_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_defs.txt" "USAGE_NORM_LIST_BUILD_A=1")
_tip_assert_file_not_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_defs.txt" "USAGE_NORM_LIST_BUILD_B=2")
_tip_assert_file_not_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_defs.txt" "BUILD_INTERFACE")
_tip_assert_file_not_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_defs.txt" "INSTALL_INTERFACE")
_tip_assert_file_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_iface_defs.txt" "USAGE_NORM_LIST_INSTALL_A=3")
_tip_assert_file_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_iface_defs.txt" "USAGE_NORM_LIST_INSTALL_B=4")
_tip_assert_file_not_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_iface_defs.txt" "USAGE_NORM_LIST_BUILD_A=1")
_tip_assert_file_not_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_iface_defs.txt" "USAGE_NORM_LIST_BUILD_B=2")
_tip_assert_file_not_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_iface_defs.txt" "BUILD_INTERFACE")
_tip_assert_file_not_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_iface_defs.txt" "INSTALL_INTERFACE")
_tip_assert_file_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_includes.txt" "${_usage_norm_list_install_prefix}/include/usage_norm_list_pkg/install_a")
_tip_assert_file_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_includes.txt" "${_usage_norm_list_install_prefix}/include/usage_norm_list_pkg/install_b")
_tip_assert_file_not_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_includes.txt" "${_usage_norm_list_dir}/build-only-include")
_tip_assert_file_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_iface_includes.txt" "${_usage_norm_list_install_prefix}/include/usage_norm_list_pkg/install_a")
_tip_assert_file_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_iface_includes.txt" "${_usage_norm_list_install_prefix}/include/usage_norm_list_pkg/install_b")
_tip_assert_file_not_contains("${_usage_norm_list_consumer_build_dir}/usage_norm_list_iface_includes.txt" "${_usage_norm_list_dir}/build-only-include")

set(_usage_norm_list_consumer_executable_candidates
    "${_usage_norm_list_consumer_build_dir}/usage_norm_list_consumer${_tip_executable_suffix}"
    "${_usage_norm_list_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/usage_norm_list_consumer${_tip_executable_suffix}"
    "${_usage_norm_list_consumer_build_dir}/usage_norm_list_consumer"
    "${_usage_norm_list_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/usage_norm_list_consumer")
_tip_find_existing_path(_usage_norm_list_consumer_executable ${_usage_norm_list_consumer_executable_candidates})
_tip_run_step(NAME "run-usage-normalization-list-payloads-consumer" COMMAND "${_usage_norm_list_consumer_executable}")

set(_late_capture_dir "${_case_root}/late-capture")
set(_late_capture_build_dir "${_late_capture_dir}/build")
set(_late_capture_install_prefix "${_late_capture_dir}/install")
file(MAKE_DIRECTORY "${_late_capture_dir}/include/late_pkg" "${_late_capture_dir}/src")

file(
  WRITE
  "${_late_capture_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_late_capture LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(late_helper STATIC src/helper.cpp)\n"
  "add_library(late_owner INTERFACE)\n"
  "add_library(late STATIC)\n"
  "target_install_package(late_owner EXPORT_NAME late_pkg NAMESPACE LatePkg:: ADDITIONAL_TARGETS late_helper)\n"
  "target_install_package(late EXPORT_NAME late_pkg NAMESPACE LatePkg:: INCLUDE_SOURCES EXCLUSIVE)\n"
  "target_sources(late PRIVATE src/late.cpp PUBLIC FILE_SET HEADERS BASE_DIRS \"${_late_capture_dir}/include\" FILES \"include/late_pkg/late.hpp\")\n"
  "target_link_libraries(late PRIVATE late_helper)\n"
  "target_link_options(late PRIVATE \"$<$<BOOL:0>:LINKER:-z,defs>\")\n"
  "target_compile_features(late PUBLIC cxx_std_17)\n")
file(
  WRITE
  "${_late_capture_dir}/include/late_pkg/late.hpp"
  "#pragma once\n"
  "int late_value();\n")
file(
  WRITE
  "${_late_capture_dir}/src/helper.cpp"
  "int late_helper_value(){return 4;}\n")
file(
  WRITE
  "${_late_capture_dir}/src/late.cpp"
  "#include \"late_pkg/late.hpp\"\n"
  "int late_helper_value();\n"
  "int late_value(){return late_helper_value()+6;}\n")

set(_late_capture_configure_command "${CMAKE_COMMAND}" -S "${_late_capture_dir}" -B "${_late_capture_build_dir}"
                                    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _late_capture_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _late_capture_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _late_capture_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _late_capture_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _late_capture_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _late_capture_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _late_capture_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-late-capture" COMMAND ${_late_capture_configure_command})
_tip_run_step(NAME "build-late-capture" COMMAND "${CMAKE_COMMAND}" --build "${_late_capture_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-late-capture"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_late_capture_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_late_capture_install_prefix}")

set(_late_capture_cache_file "${_late_capture_build_dir}/CMakeCache.txt")
_tip_assert_exists("${_late_capture_cache_file}")
_tip_read_cache_entry("${_late_capture_cache_file}" "CMAKE_INSTALL_DATADIR" _late_capture_install_datadir)
_tip_read_cache_entry("${_late_capture_cache_file}" "CMAKE_INSTALL_DATAROOTDIR" _late_capture_install_datarootdir)
if(_late_capture_install_datadir STREQUAL "")
  if(_late_capture_install_datarootdir STREQUAL "")
    set(_late_capture_install_datadir "share")
  else()
    set(_late_capture_install_datadir "${_late_capture_install_datarootdir}")
  endif()
endif()

set(_late_capture_installed_source "${_late_capture_install_prefix}/${_late_capture_install_datadir}/late_pkg/late/src/late.cpp")
_tip_assert_exists("${_late_capture_installed_source}")

set(_late_capture_consumer_dir "${_late_capture_dir}/consumer")
set(_late_capture_consumer_build_dir "${_late_capture_consumer_dir}/build")
file(MAKE_DIRECTORY "${_late_capture_consumer_dir}")

file(
  WRITE
  "${_late_capture_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_late_capture_consumer LANGUAGES CXX)

find_package(late_pkg CONFIG REQUIRED)

get_target_property(_late_local_target LatePkg::late ALIASED_TARGET)
if(NOT _late_local_target)
  message(FATAL_ERROR "LatePkg::late is not an alias target")
endif()
get_target_property(_late_type "${_late_local_target}" TYPE)
get_target_property(_late_sources "${_late_local_target}" SOURCES)
get_target_property(_late_links "${_late_local_target}" LINK_LIBRARIES)
get_target_property(_late_link_options "${_late_local_target}" LINK_OPTIONS)
get_target_property(_late_helper_imported LatePkg::late_helper IMPORTED)
file(WRITE "${CMAKE_BINARY_DIR}/late_type.txt" "${_late_type}\n")
file(WRITE "${CMAKE_BINARY_DIR}/late_sources.txt" "${_late_sources}\n")
file(WRITE "${CMAKE_BINARY_DIR}/late_links.txt" "${_late_links}\n")
file(WRITE "${CMAKE_BINARY_DIR}/late_link_options.txt" "${_late_link_options}\n")
file(WRITE "${CMAKE_BINARY_DIR}/late_helper_imported.txt" "${_late_helper_imported}\n")

add_executable(late_capture_consumer main.cpp)
target_link_libraries(late_capture_consumer PRIVATE LatePkg::late)
]=])

file(
  WRITE
  "${_late_capture_consumer_dir}/main.cpp"
  [=[
#include "late_pkg/late.hpp"

int main() {
  return late_value() == 10 ? 0 : 1;
}
]=])

set(_late_capture_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_late_capture_consumer_dir}"
    -B
    "${_late_capture_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_late_capture_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _late_capture_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _late_capture_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _late_capture_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _late_capture_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _late_capture_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _late_capture_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _late_capture_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-late-capture-consumer" COMMAND ${_late_capture_consumer_configure_command})
_tip_run_step(
  NAME
  "build-late-capture-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_late_capture_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_assert_file_contains("${_late_capture_consumer_build_dir}/late_type.txt" "STATIC_LIBRARY")
_tip_assert_file_contains("${_late_capture_consumer_build_dir}/late_sources.txt" "${_late_capture_installed_source}")
_tip_assert_file_contains("${_late_capture_consumer_build_dir}/late_links.txt" "LatePkg::late_helper")
_tip_assert_file_contains("${_late_capture_consumer_build_dir}/late_link_options.txt" "BOOL:0")
_tip_assert_file_contains("${_late_capture_consumer_build_dir}/late_helper_imported.txt" "TRUE")

set(_late_capture_consumer_executable_candidates
    "${_late_capture_consumer_build_dir}/late_capture_consumer${_tip_executable_suffix}"
    "${_late_capture_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/late_capture_consumer${_tip_executable_suffix}"
    "${_late_capture_consumer_build_dir}/late_capture_consumer"
    "${_late_capture_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/late_capture_consumer")
_tip_find_existing_path(_late_capture_consumer_executable ${_late_capture_consumer_executable_candidates})
_tip_run_step(NAME "run-late-capture-consumer" COMMAND "${_late_capture_consumer_executable}")

set(_conditional_private_link_dir "${_case_root}/conditional-private-link-remap")
set(_conditional_private_link_build_dir "${_conditional_private_link_dir}/build")
set(_conditional_private_link_install_prefix "${_conditional_private_link_dir}/install")
file(MAKE_DIRECTORY "${_conditional_private_link_dir}/include/conditional_pkg" "${_conditional_private_link_dir}/src")

file(
  WRITE
  "${_conditional_private_link_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_conditional_private_link LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(cond_dep STATIC src/dep.cpp)\n"
  "target_sources(cond_dep PUBLIC FILE_SET HEADERS BASE_DIRS \"${_conditional_private_link_dir}/include\" FILES \"include/conditional_pkg/dep.hpp\")\n"
  "add_library(cond_user STATIC src/user.cpp)\n"
  "target_sources(cond_user PUBLIC FILE_SET HEADERS BASE_DIRS \"${_conditional_private_link_dir}/include\" FILES \"include/conditional_pkg/user.hpp\")\n"
  "target_link_libraries(cond_user PRIVATE \"$<$<BOOL:1>:cond_dep>\")\n"
  "target_install_package(cond_dep EXPORT_NAME conditional_pkg NAMESPACE ConditionalPkg:: INCLUDE_SOURCES EXCLUSIVE)\n"
  "target_install_package(cond_user EXPORT_NAME conditional_pkg NAMESPACE ConditionalPkg:: INCLUDE_SOURCES EXCLUSIVE)\n")
file(
  WRITE
  "${_conditional_private_link_dir}/include/conditional_pkg/dep.hpp"
  "#pragma once\n"
  "int conditional_dep_value();\n")
file(
  WRITE
  "${_conditional_private_link_dir}/include/conditional_pkg/user.hpp"
  "#pragma once\n"
  "int conditional_user_value();\n")
file(
  WRITE
  "${_conditional_private_link_dir}/src/dep.cpp"
  "#include \"conditional_pkg/dep.hpp\"\n"
  "int conditional_dep_value(){return 4;}\n")
file(
  WRITE
  "${_conditional_private_link_dir}/src/user.cpp"
  "#include \"conditional_pkg/user.hpp\"\n"
  "#include \"conditional_pkg/dep.hpp\"\n"
  "int conditional_user_value(){return conditional_dep_value()+1;}\n")

set(_conditional_private_link_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_conditional_private_link_dir}"
    -B
    "${_conditional_private_link_build_dir}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _conditional_private_link_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _conditional_private_link_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _conditional_private_link_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _conditional_private_link_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _conditional_private_link_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _conditional_private_link_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _conditional_private_link_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-conditional-private-link-remap" COMMAND ${_conditional_private_link_configure_command})
_tip_run_step(NAME "build-conditional-private-link-remap" COMMAND "${CMAKE_COMMAND}" --build "${_conditional_private_link_build_dir}" --config "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-conditional-private-link-remap"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_conditional_private_link_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}"
  --prefix
  "${_conditional_private_link_install_prefix}")

set(_conditional_private_link_consumer_dir "${_conditional_private_link_dir}/consumer")
set(_conditional_private_link_consumer_build_dir "${_conditional_private_link_consumer_dir}/build")
file(MAKE_DIRECTORY "${_conditional_private_link_consumer_dir}")

file(
  WRITE
  "${_conditional_private_link_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_conditional_private_link_consumer LANGUAGES CXX)

find_package(conditional_pkg CONFIG REQUIRED)

get_target_property(_conditional_local_target ConditionalPkg::cond_user ALIASED_TARGET)
if(NOT _conditional_local_target)
  message(FATAL_ERROR "ConditionalPkg::cond_user is not an alias target")
endif()
get_target_property(_conditional_links "${_conditional_local_target}" LINK_LIBRARIES)
get_target_property(_conditional_iface_links "${_conditional_local_target}" INTERFACE_LINK_LIBRARIES)
file(WRITE "${CMAKE_BINARY_DIR}/conditional_links.txt" "${_conditional_links}\n")
file(WRITE "${CMAKE_BINARY_DIR}/conditional_iface_links.txt" "${_conditional_iface_links}\n")

add_executable(conditional_private_link_consumer main.cpp)
target_link_libraries(conditional_private_link_consumer PRIVATE ConditionalPkg::cond_user)
]=])

file(
  WRITE
  "${_conditional_private_link_consumer_dir}/main.cpp"
  [=[
#include "conditional_pkg/user.hpp"

int main() {
  return conditional_user_value() == 5 ? 0 : 1;
}
]=])

set(_conditional_private_link_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_conditional_private_link_consumer_dir}"
    -B
    "${_conditional_private_link_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_conditional_private_link_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _conditional_private_link_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _conditional_private_link_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _conditional_private_link_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _conditional_private_link_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _conditional_private_link_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _conditional_private_link_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _conditional_private_link_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-conditional-private-link-remap-consumer" COMMAND ${_conditional_private_link_consumer_configure_command})
_tip_run_step(
  NAME
  "build-conditional-private-link-remap-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_conditional_private_link_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_TEST_CONFIG}")

_tip_assert_file_contains("${_conditional_private_link_consumer_build_dir}/conditional_links.txt" "ConditionalPkg::cond_dep")
_tip_assert_file_contains("${_conditional_private_link_consumer_build_dir}/conditional_iface_links.txt" "ConditionalPkg::cond_dep")
_tip_assert_file_not_contains("${_conditional_private_link_consumer_build_dir}/conditional_links.txt" "$<$<BOOL:1>:cond_dep>")
_tip_assert_file_not_contains("${_conditional_private_link_consumer_build_dir}/conditional_links.txt" "$<LINK_ONLY:$<$<BOOL:1>:cond_dep>>")
_tip_assert_file_not_contains("${_conditional_private_link_consumer_build_dir}/conditional_iface_links.txt" "$<$<BOOL:1>:cond_dep>")
_tip_assert_file_not_contains("${_conditional_private_link_consumer_build_dir}/conditional_iface_links.txt" "$<LINK_ONLY:$<$<BOOL:1>:cond_dep>>")

set(_conditional_private_link_consumer_executable_candidates
    "${_conditional_private_link_consumer_build_dir}/conditional_private_link_consumer${_tip_executable_suffix}"
    "${_conditional_private_link_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/conditional_private_link_consumer${_tip_executable_suffix}"
    "${_conditional_private_link_consumer_build_dir}/conditional_private_link_consumer"
    "${_conditional_private_link_consumer_build_dir}/${TIP_SOURCE_PACKAGE_TEST_CONFIG}/conditional_private_link_consumer")
_tip_find_existing_path(_conditional_private_link_consumer_executable ${_conditional_private_link_consumer_executable_candidates})
_tip_run_step(NAME "run-conditional-private-link-remap-consumer" COMMAND "${_conditional_private_link_consumer_executable}")

set(_invalid_genex_dir "${_case_root}/invalid-genex")
set(_invalid_genex_build_dir "${_invalid_genex_dir}/build")
file(MAKE_DIRECTORY "${_invalid_genex_dir}/src")

file(
  WRITE
  "${_invalid_genex_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_invalid_genex LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(invalid_genex STATIC)\n"
  "target_sources(invalid_genex PRIVATE \"$<BUILD_INTERFACE:$<CONFIG>/src/invalid.cpp>\")\n"
  "target_install_package(invalid_genex INCLUDE_SOURCES EXCLUSIVE)\n")
file(WRITE "${_invalid_genex_dir}/src/invalid.cpp" "int invalid_genex() { return 0; }\n")

set(_invalid_genex_configure_command "${CMAKE_COMMAND}" -S "${_invalid_genex_dir}" -B "${_invalid_genex_build_dir}" "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _invalid_genex_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _invalid_genex_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _invalid_genex_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _invalid_genex_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _invalid_genex_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _invalid_genex_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _invalid_genex_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

execute_process(
  COMMAND ${_invalid_genex_configure_command}
  RESULT_VARIABLE _invalid_genex_result
  OUTPUT_VARIABLE _invalid_genex_stdout
  ERROR_VARIABLE _invalid_genex_stderr)

if(_invalid_genex_result EQUAL 0)
  _tip_fail("Expected unsupported SOURCES generator expression configure to fail")
endif()

set(_invalid_genex_output "${_invalid_genex_stdout}\n${_invalid_genex_stderr}")
string(FIND "${_invalid_genex_output}" "SOURCES generator expression" _invalid_genex_match_index)
if(_invalid_genex_match_index EQUAL -1)
  _tip_fail("Expected validation error for unsupported INCLUDE_SOURCES EXCLUSIVE generator expression usage")
endif()

message(STATUS "[source-package] Source package assertions passed.")
