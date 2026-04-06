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

set(_installed_source "${_install_prefix}/${_install_datadir}/source_sdk/export_algorithms/src/algorithms.cpp")
set(_installed_header "${_install_prefix}/${_install_includedir}/source_sdk/sdk.hpp")
set(_installed_config "${_install_prefix}/${_install_datadir}/cmake/source_sdk/source_sdkConfig.cmake")

_tip_assert_exists("${_installed_source}")
_tip_assert_exists("${_installed_header}")
_tip_assert_exists("${_installed_config}")
_tip_assert_file_contains("${_installed_config}" "find_dependency(Threads)")

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

get_target_property(_source_sdk_algorithms_target SourceSdk::export_algorithms ALIASED_TARGET)
if(NOT _source_sdk_algorithms_target)
  message(FATAL_ERROR "SourceSdk::export_algorithms is not an alias target")
endif()
get_target_property(_source_sdk_algorithms_imported "${_source_sdk_algorithms_target}" IMPORTED)
if(_source_sdk_algorithms_imported)
  message(FATAL_ERROR "SourceSdk::export_algorithms resolved to an imported target")
endif()
get_target_property(_source_sdk_algorithms_sources "${_source_sdk_algorithms_target}" SOURCES)
if(NOT _source_sdk_algorithms_sources)
  message(FATAL_ERROR "SourceSdk::export_algorithms did not expose local SOURCES")
endif()
get_target_property(_source_sdk_algorithms_type "${_source_sdk_algorithms_target}" TYPE)
get_target_property(_source_sdk_algorithms_links "${_source_sdk_algorithms_target}" LINK_LIBRARIES)
get_target_property(_source_sdk_algorithms_interface_links "${_source_sdk_algorithms_target}" INTERFACE_LINK_LIBRARIES)
get_target_property(_source_sdk_algorithms_link_options "${_source_sdk_algorithms_target}" LINK_OPTIONS)
get_target_property(_source_sdk_algorithms_interface_link_options "${_source_sdk_algorithms_target}" INTERFACE_LINK_OPTIONS)
get_target_property(_source_sdk_algorithms_pic "${_source_sdk_algorithms_target}" POSITION_INDEPENDENT_CODE)

get_target_property(_source_sdk_prebuilt_target SourceSdk::export_algorithms_prebuilt ALIASED_TARGET)
if(_source_sdk_prebuilt_target)
  set(_source_sdk_prebuilt_check_target "${_source_sdk_prebuilt_target}")
else()
  set(_source_sdk_prebuilt_check_target "SourceSdk::export_algorithms_prebuilt")
endif()
get_target_property(_source_sdk_prebuilt_imported "${_source_sdk_prebuilt_check_target}" IMPORTED)
if(NOT _source_sdk_prebuilt_imported)
  message(FATAL_ERROR "SourceSdk::export_algorithms_prebuilt is expected to stay imported")
endif()

get_target_property(_source_sdk_sdk_target SourceSdk::export_sdk ALIASED_TARGET)
if(NOT _source_sdk_sdk_target)
  message(FATAL_ERROR "SourceSdk::export_sdk is not an alias target")
endif()
get_target_property(_source_sdk_sdk_imported "${_source_sdk_sdk_target}" IMPORTED)
if(_source_sdk_sdk_imported)
  message(FATAL_ERROR "SourceSdk::export_sdk resolved to an imported target")
endif()
get_target_property(_source_sdk_sdk_links "${_source_sdk_sdk_target}" INTERFACE_LINK_LIBRARIES)
file(WRITE "${CMAKE_BINARY_DIR}/source_sdk_algorithms_sources.txt" "${_source_sdk_algorithms_sources}\n")
file(WRITE "${CMAKE_BINARY_DIR}/source_sdk_algorithms_type.txt" "${_source_sdk_algorithms_type}\n")
file(WRITE "${CMAKE_BINARY_DIR}/source_sdk_algorithms_links.txt" "${_source_sdk_algorithms_links}\n")
file(WRITE "${CMAKE_BINARY_DIR}/source_sdk_algorithms_interface_links.txt" "${_source_sdk_algorithms_interface_links}\n")
file(WRITE "${CMAKE_BINARY_DIR}/source_sdk_algorithms_link_options.txt" "${_source_sdk_algorithms_link_options}\n")
file(WRITE "${CMAKE_BINARY_DIR}/source_sdk_algorithms_interface_link_options.txt" "${_source_sdk_algorithms_interface_link_options}\n")
file(WRITE "${CMAKE_BINARY_DIR}/source_sdk_algorithms_pic.txt" "${_source_sdk_algorithms_pic}\n")
file(WRITE "${CMAKE_BINARY_DIR}/source_sdk_sdk_links.txt" "${_source_sdk_sdk_links}\n")

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
  const bool score_ok = source_sdk::algorithms::score(values) == 28;

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

set(_consumer_sources_file "${_consumer_build_dir}/source_sdk_algorithms_sources.txt")
set(_consumer_type_file "${_consumer_build_dir}/source_sdk_algorithms_type.txt")
set(_consumer_links_file "${_consumer_build_dir}/source_sdk_algorithms_links.txt")
set(_consumer_interface_links_file "${_consumer_build_dir}/source_sdk_algorithms_interface_links.txt")
set(_consumer_link_options_file "${_consumer_build_dir}/source_sdk_algorithms_link_options.txt")
set(_consumer_interface_link_options_file "${_consumer_build_dir}/source_sdk_algorithms_interface_link_options.txt")
set(_consumer_pic_file "${_consumer_build_dir}/source_sdk_algorithms_pic.txt")
set(_consumer_sdk_links_file "${_consumer_build_dir}/source_sdk_sdk_links.txt")
_tip_assert_file_contains("${_consumer_sources_file}" "${_installed_source}")
_tip_assert_file_not_contains("${_consumer_sources_file}" "${_fixture_source_dir}/src/algorithms.cpp")
_tip_assert_file_contains("${_consumer_type_file}" "STATIC_LIBRARY")
_tip_assert_file_contains("${_consumer_links_file}" "SourceSdk::export_runtime")
_tip_assert_file_contains("${_consumer_links_file}" "SourceSdk::export_support")
_tip_assert_file_contains("${_consumer_links_file}" "Threads::Threads")
_tip_assert_file_contains("${_consumer_interface_links_file}" "SourceSdk::export_runtime")
_tip_assert_file_contains("${_consumer_pic_file}" "ON")
_tip_assert_file_contains("${_consumer_sdk_links_file}" "SourceSdk::export_algorithms")
_tip_assert_file_contains("${_consumer_sdk_links_file}" "SourceSdk::export_runtime")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  _tip_assert_file_contains("${_consumer_link_options_file}" "LINKER:-z,origin")
  _tip_assert_file_not_contains("${_consumer_link_options_file}" "LINKER:-z,defs")
  _tip_assert_file_contains("${_consumer_interface_link_options_file}" "LINKER:-z,origin")
  _tip_assert_file_not_contains("${_consumer_interface_link_options_file}" "LINKER:-z,defs")
endif()

set(_consumer_executable_candidates
    "${_consumer_build_dir}/source_package_export_consumer${_tip_executable_suffix}"
    "${_consumer_build_dir}/${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}/source_package_export_consumer${_tip_executable_suffix}"
    "${_consumer_build_dir}/source_package_export_consumer"
    "${_consumer_build_dir}/${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}/source_package_export_consumer")
_tip_find_existing_path(_consumer_executable ${_consumer_executable_candidates})
_tip_run_step(NAME "run-consumer" COMMAND "${_consumer_executable}")

set(_shared_consumer_dir "${_case_root}/shared-consumer")
set(_shared_consumer_build_dir "${_shared_consumer_dir}/build")
file(MAKE_DIRECTORY "${_shared_consumer_dir}")

file(
  WRITE
  "${_shared_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_export_shared_consumer LANGUAGES CXX)

set(BUILD_SHARED_LIBS ON)
find_package(source_sdk CONFIG REQUIRED)

get_target_property(_algorithms_local_target SourceSdk::export_algorithms ALIASED_TARGET)
if(NOT _algorithms_local_target)
  message(FATAL_ERROR "SourceSdk::export_algorithms is not an alias target")
endif()
get_target_property(_algorithms_type "${_algorithms_local_target}" TYPE)
get_target_property(_algorithms_exports "${_algorithms_local_target}" WINDOWS_EXPORT_ALL_SYMBOLS)
file(WRITE "${CMAKE_BINARY_DIR}/shared_algorithms_type.txt" "${_algorithms_type}\n")
file(WRITE "${CMAKE_BINARY_DIR}/shared_algorithms_exports.txt" "${_algorithms_exports}\n")

add_executable(source_package_export_shared_consumer main.cpp)
target_compile_features(source_package_export_shared_consumer PRIVATE cxx_std_17)
target_link_libraries(source_package_export_shared_consumer PRIVATE SourceSdk::export_algorithms)
]=])

file(
  WRITE
  "${_shared_consumer_dir}/main.cpp"
  [=[
#include "source_sdk/algorithms.hpp"

#include <vector>

int main() {
  const std::vector<int> values{1, 2, 3};
  return source_sdk::algorithms::score(values) == 28 ? 0 : 1;
}
]=])

set(_shared_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_shared_consumer_dir}"
    -B
    "${_shared_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _shared_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _shared_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _shared_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _shared_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _shared_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _shared_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _shared_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-shared-consumer" COMMAND ${_shared_consumer_configure_command})
_tip_run_step(
  NAME
  "build-shared-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_shared_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")

_tip_assert_file_contains("${_shared_consumer_build_dir}/shared_algorithms_type.txt" "SHARED_LIBRARY")
_tip_assert_file_contains("${_shared_consumer_build_dir}/shared_algorithms_exports.txt" "ON")

set(_shared_consumer_executable_candidates
    "${_shared_consumer_build_dir}/source_package_export_shared_consumer${_tip_executable_suffix}"
    "${_shared_consumer_build_dir}/${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}/source_package_export_shared_consumer${_tip_executable_suffix}"
    "${_shared_consumer_build_dir}/source_package_export_shared_consumer"
    "${_shared_consumer_build_dir}/${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}/source_package_export_shared_consumer")
_tip_find_existing_path(_shared_consumer_executable ${_shared_consumer_executable_candidates})
_tip_run_step(NAME "run-shared-consumer" COMMAND "${_shared_consumer_executable}")

set(_template_compat_dir "${_case_root}/custom-template-compat")
set(_template_compat_build_dir "${_template_compat_dir}/build")
set(_template_compat_install_prefix "${_template_compat_dir}/install")
file(MAKE_DIRECTORY "${_template_compat_dir}/include/compat_pkg" "${_template_compat_dir}/src" "${_template_compat_dir}/cmake")

file(
  WRITE
  "${_template_compat_dir}/cmake/custom-config.cmake.in"
  [=[
@PACKAGE_INIT@
include(CMakeFindDependencyMacro)
@PACKAGE_PUBLIC_DEPENDENCIES_CONTENT@
@PACKAGE_COMPONENT_DEPENDENCIES_CONTENT@
@PACKAGE_INCLUDE_ON_FIND_PACKAGE@
include("${CMAKE_CURRENT_LIST_DIR}/${CMAKE_FIND_PACKAGE_NAME}Targets.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/${CMAKE_FIND_PACKAGE_NAME}SourceTargets.cmake")
check_required_components(@ARG_EXPORT_NAME@)
]=])

file(
  WRITE
  "${_template_compat_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_custom_template_compat LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(prebuilt STATIC src/prebuilt.cpp)\n"
  "target_sources(prebuilt PUBLIC FILE_SET HEADERS BASE_DIRS \"${_template_compat_dir}/include\" FILES \"include/compat_pkg/prebuilt.hpp\")\n"
  "add_library(from_source STATIC src/from_source.cpp)\n"
  "target_sources(from_source PUBLIC FILE_SET HEADERS BASE_DIRS \"${_template_compat_dir}/include\" FILES \"include/compat_pkg/from_source.hpp\")\n"
  "target_link_libraries(from_source PUBLIC prebuilt)\n"
  "target_install_package(prebuilt EXPORT_NAME compat_pkg NAMESPACE CompatPkg:: CONFIG_TEMPLATE \"${_template_compat_dir}/cmake/custom-config.cmake.in\")\n"
  "target_install_package(from_source EXPORT_NAME compat_pkg NAMESPACE CompatPkg:: INCLUDE_SOURCES EXCLUSIVE CONFIG_TEMPLATE \"${_template_compat_dir}/cmake/custom-config.cmake.in\")\n")
file(
  WRITE
  "${_template_compat_dir}/include/compat_pkg/prebuilt.hpp"
  "#pragma once\n"
  "int compat_prebuilt_value();\n")
file(
  WRITE
  "${_template_compat_dir}/include/compat_pkg/from_source.hpp"
  "#pragma once\n"
  "int compat_from_source_value();\n")
file(
  WRITE
  "${_template_compat_dir}/src/prebuilt.cpp"
  "#include \"compat_pkg/prebuilt.hpp\"\n"
  "int compat_prebuilt_value(){return 4;}\n")
file(
  WRITE
  "${_template_compat_dir}/src/from_source.cpp"
  "#include \"compat_pkg/from_source.hpp\"\n"
  "#include \"compat_pkg/prebuilt.hpp\"\n"
  "int compat_from_source_value(){return compat_prebuilt_value()+5;}\n")

set(_template_compat_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_template_compat_dir}"
    -B
    "${_template_compat_build_dir}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _template_compat_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _template_compat_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _template_compat_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _template_compat_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _template_compat_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _template_compat_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _template_compat_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-custom-template-compat" COMMAND ${_template_compat_configure_command})
_tip_run_step(
  NAME
  "build-custom-template-compat"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_template_compat_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")
_tip_run_step(
  NAME
  "install-custom-template-compat"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_template_compat_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}"
  --prefix
  "${_template_compat_install_prefix}")

set(_template_compat_consumer_dir "${_template_compat_dir}/consumer")
set(_template_compat_consumer_build_dir "${_template_compat_consumer_dir}/build")
file(MAKE_DIRECTORY "${_template_compat_consumer_dir}")

file(
  WRITE
  "${_template_compat_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(source_package_custom_template_compat_consumer LANGUAGES CXX)

find_package(compat_pkg CONFIG REQUIRED)

add_executable(custom_template_compat_consumer main.cpp)
target_link_libraries(custom_template_compat_consumer PRIVATE CompatPkg::from_source)
]=])

file(
  WRITE
  "${_template_compat_consumer_dir}/main.cpp"
  [=[
#include "compat_pkg/from_source.hpp"

int main() {
  return compat_from_source_value() == 9 ? 0 : 1;
}
]=])

set(_template_compat_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_template_compat_consumer_dir}"
    -B
    "${_template_compat_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_template_compat_install_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _template_compat_consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _template_compat_consumer_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _template_compat_consumer_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _template_compat_consumer_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _template_compat_consumer_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _template_compat_consumer_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _template_compat_consumer_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-custom-template-compat-consumer" COMMAND ${_template_compat_consumer_configure_command})
_tip_run_step(
  NAME
  "build-custom-template-compat-consumer"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_template_compat_consumer_build_dir}"
  --config
  "${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")

set(_template_compat_consumer_executable_candidates
    "${_template_compat_consumer_build_dir}/custom_template_compat_consumer${_tip_executable_suffix}"
    "${_template_compat_consumer_build_dir}/${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}/custom_template_compat_consumer${_tip_executable_suffix}"
    "${_template_compat_consumer_build_dir}/custom_template_compat_consumer"
    "${_template_compat_consumer_build_dir}/${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}/custom_template_compat_consumer")
_tip_find_existing_path(_template_compat_consumer_executable ${_template_compat_consumer_executable_candidates})
_tip_run_step(NAME "run-custom-template-compat-consumer" COMMAND "${_template_compat_consumer_executable}")

set(_exclusive_template_dir "${_case_root}/custom-template-exclusive-only")
set(_exclusive_template_build_dir "${_exclusive_template_dir}/build")
file(MAKE_DIRECTORY "${_exclusive_template_dir}/include/onlysrc" "${_exclusive_template_dir}/src" "${_exclusive_template_dir}/cmake")

file(
  WRITE
  "${_exclusive_template_dir}/cmake/custom-config.cmake.in"
  [=[
@PACKAGE_INIT@
@PACKAGE_PUBLIC_DEPENDENCIES_CONTENT@
@PACKAGE_COMPONENT_DEPENDENCIES_CONTENT@
@PACKAGE_INCLUDE_ON_FIND_PACKAGE@
include("${CMAKE_CURRENT_LIST_DIR}/onlysrcTargets.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/onlysrcSourceTargets.cmake")
check_required_components(@ARG_EXPORT_NAME@)
]=])

file(
  WRITE
  "${_exclusive_template_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_custom_template_exclusive_only LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(onlysrc STATIC src/onlysrc.cpp)\n"
  "target_sources(onlysrc PUBLIC FILE_SET HEADERS BASE_DIRS \"${_exclusive_template_dir}/include\" FILES \"include/onlysrc/onlysrc.hpp\")\n"
  "target_install_package(onlysrc EXPORT_NAME onlysrc NAMESPACE OnlySrc:: INCLUDE_SOURCES EXCLUSIVE CONFIG_TEMPLATE \"${_exclusive_template_dir}/cmake/custom-config.cmake.in\")\n")
file(
  WRITE
  "${_exclusive_template_dir}/include/onlysrc/onlysrc.hpp"
  "#pragma once\n"
  "int onlysrc_value();\n")
file(
  WRITE
  "${_exclusive_template_dir}/src/onlysrc.cpp"
  "#include \"onlysrc/onlysrc.hpp\"\n"
  "int onlysrc_value(){return 17;}\n")

set(_exclusive_template_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_exclusive_template_dir}"
    -B
    "${_exclusive_template_build_dir}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _exclusive_template_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _exclusive_template_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _exclusive_template_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _exclusive_template_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _exclusive_template_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _exclusive_template_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _exclusive_template_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

execute_process(
  COMMAND ${_exclusive_template_configure_command}
  RESULT_VARIABLE _exclusive_template_result
  OUTPUT_VARIABLE _exclusive_template_stdout
  ERROR_VARIABLE _exclusive_template_stderr)

if(_exclusive_template_result EQUAL 0)
  _tip_fail("Expected exclusive-only legacy custom template to fail validation")
endif()

set(_exclusive_template_output "${_exclusive_template_stdout}\n${_exclusive_template_stderr}")
string(FIND "${_exclusive_template_output}" "export Targets.cmake file" _exclusive_template_targets_match)
if(_exclusive_template_targets_match EQUAL -1)
  _tip_fail("Expected exclusive-only template validation error to name the direct Targets.cmake include")
endif()
string(FIND "${_exclusive_template_output}" "no imported targets" _exclusive_template_imported_match)
if(_exclusive_template_imported_match EQUAL -1)
  _tip_fail("Expected exclusive-only template validation error to explain that no imported targets are installed")
endif()

set(_import_only_template_dir "${_case_root}/custom-template-import-only")
set(_import_only_template_build_dir "${_import_only_template_dir}/build")
file(MAKE_DIRECTORY "${_import_only_template_dir}/include/plain" "${_import_only_template_dir}/src" "${_import_only_template_dir}/cmake")

file(
  WRITE
  "${_import_only_template_dir}/cmake/custom-config.cmake.in"
  [=[
@PACKAGE_INIT@
@PACKAGE_PUBLIC_DEPENDENCIES_CONTENT@
@PACKAGE_COMPONENT_DEPENDENCIES_CONTENT@
@PACKAGE_INCLUDE_ON_FIND_PACKAGE@
include("${CMAKE_CURRENT_LIST_DIR}/plainTargets.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/plainSourceTargets.cmake")
check_required_components(@ARG_EXPORT_NAME@)
]=])

file(
  WRITE
  "${_import_only_template_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_custom_template_import_only LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(plain STATIC src/plain.cpp)\n"
  "target_sources(plain PUBLIC FILE_SET HEADERS BASE_DIRS \"${_import_only_template_dir}/include\" FILES \"include/plain/plain.hpp\")\n"
  "target_install_package(plain EXPORT_NAME plain NAMESPACE Plain:: CONFIG_TEMPLATE \"${_import_only_template_dir}/cmake/custom-config.cmake.in\")\n")
file(
  WRITE
  "${_import_only_template_dir}/include/plain/plain.hpp"
  "#pragma once\n"
  "int plain_value();\n")
file(
  WRITE
  "${_import_only_template_dir}/src/plain.cpp"
  "#include \"plain/plain.hpp\"\n"
  "int plain_value(){return 23;}\n")

set(_import_only_template_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_import_only_template_dir}"
    -B
    "${_import_only_template_build_dir}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _import_only_template_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _import_only_template_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _import_only_template_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _import_only_template_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _import_only_template_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _import_only_template_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _import_only_template_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

execute_process(
  COMMAND ${_import_only_template_configure_command}
  RESULT_VARIABLE _import_only_template_result
  OUTPUT_VARIABLE _import_only_template_stdout
  ERROR_VARIABLE _import_only_template_stderr)

if(_import_only_template_result EQUAL 0)
  _tip_fail("Expected import-only legacy custom template to fail validation")
endif()

set(_import_only_template_output "${_import_only_template_stdout}\n${_import_only_template_stderr}")
string(FIND "${_import_only_template_output}" "export SourceTargets.cmake file" _import_only_template_targets_match)
if(_import_only_template_targets_match EQUAL -1)
  _tip_fail("Expected import-only template validation error to name the direct SourceTargets.cmake include")
endif()
string(FIND "${_import_only_template_output}" "no source-backed targets" _import_only_template_source_match)
if(_import_only_template_source_match EQUAL -1)
  _tip_fail("Expected import-only template validation error to explain that no source-backed targets are installed")
endif()

set(_comment_template_dir "${_case_root}/custom-template-comment-note")
set(_comment_template_build_dir "${_comment_template_dir}/build")
file(MAKE_DIRECTORY "${_comment_template_dir}/include/commented" "${_comment_template_dir}/src" "${_comment_template_dir}/cmake")

file(
  WRITE
  "${_comment_template_dir}/cmake/custom-config.cmake.in"
  [=[
@PACKAGE_INIT@
@PACKAGE_PUBLIC_DEPENDENCIES_CONTENT@
@PACKAGE_COMPONENT_DEPENDENCIES_CONTENT@
@PACKAGE_INCLUDE_ON_FIND_PACKAGE@
set(_pkg "${CMAKE_FIND_PACKAGE_NAME}") # legacy note: include("${CMAKE_CURRENT_LIST_DIR}/commentedSourceTargets.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/${_pkg}Targets.cmake") # legacy note: include("${CMAKE_CURRENT_LIST_DIR}/commentedTargets.cmake")
check_required_components(@ARG_EXPORT_NAME@)
]=])

file(
  WRITE
  "${_comment_template_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(source_package_custom_template_comment_note LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/list_file_include_guard.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/project_log.cmake\")\n"
  "include(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\n"
  "add_library(commented STATIC src/commented.cpp)\n"
  "target_sources(commented PUBLIC FILE_SET HEADERS BASE_DIRS \"${_comment_template_dir}/include\" FILES \"include/commented/commented.hpp\")\n"
  "target_install_package(commented EXPORT_NAME commented NAMESPACE Commented:: CONFIG_TEMPLATE \"${_comment_template_dir}/cmake/custom-config.cmake.in\")\n")
file(
  WRITE
  "${_comment_template_dir}/include/commented/commented.hpp"
  "#pragma once\n"
  "int commented_value();\n")
file(
  WRITE
  "${_comment_template_dir}/src/commented.cpp"
  "#include \"commented/commented.hpp\"\n"
  "int commented_value(){return 29;}\n")

set(_comment_template_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_comment_template_dir}"
    -B
    "${_comment_template_build_dir}"
    "-DCMAKE_BUILD_TYPE=${TIP_SOURCE_PACKAGE_EXPORT_TEST_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _comment_template_configure_command -G "${TIP_CMAKE_GENERATOR}")
endif()
if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
  list(APPEND _comment_template_configure_command "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
endif()
if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
  list(APPEND _comment_template_configure_command "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
endif()
if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
  list(APPEND _comment_template_configure_command "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
endif()
if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
  list(APPEND _comment_template_configure_command "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
  list(APPEND _comment_template_configure_command "-A" "${TIP_CMAKE_GENERATOR_PLATFORM}")
endif()
if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
  list(APPEND _comment_template_configure_command "-T" "${TIP_CMAKE_GENERATOR_TOOLSET}")
endif()

_tip_run_step(NAME "configure-comment-template-note" COMMAND ${_comment_template_configure_command})

message(STATUS "[source-package-export] Shared export source-package assertions passed.")
