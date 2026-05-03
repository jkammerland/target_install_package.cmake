cmake_minimum_required(VERSION 3.25)

function(_tip_fail text)
  message(FATAL_ERROR "[layout-matrix] ${text}")
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
    message(STATUS "[layout-matrix] Step '${ARG_NAME}' failed.")
    if(NOT _stdout STREQUAL "")
      message(STATUS "[layout-matrix][stdout]\n${_stdout}")
    endif()
    if(NOT _stderr STREQUAL "")
      message(STATUS "[layout-matrix][stderr]\n${_stderr}")
    endif()
    _tip_fail("Step '${ARG_NAME}' exited with code ${_result}")
  endif()
endfunction()

function(_tip_assert_exists path)
  if(NOT EXISTS "${path}")
    _tip_fail("Expected path does not exist: ${path}")
  endif()
endfunction()

function(_tip_assert_not_exists path)
  if(EXISTS "${path}")
    _tip_fail("Path should not exist: ${path}")
  endif()
endfunction()

function(_tip_assert_glob_exists dir pattern)
  file(GLOB _matches "${dir}/${pattern}")
  if(NOT _matches)
    _tip_fail("Expected files matching '${pattern}' under '${dir}'")
  endif()
endfunction()

function(_tip_assert_glob_absent dir pattern)
  file(GLOB _matches "${dir}/${pattern}")
  if(_matches)
    _tip_fail("Unexpected files matching '${pattern}' under '${dir}': ${_matches}")
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

function(_tip_assert_any_file_contains needle)
  set(_tip_found FALSE)
  foreach(path IN LISTS ARGN)
    if(EXISTS "${path}")
      file(READ "${path}" _content)
      string(FIND "${_content}" "${needle}" _match_index)
      if(NOT _match_index EQUAL -1)
        set(_tip_found TRUE)
        break()
      endif()
    endif()
  endforeach()
  if(NOT _tip_found)
    _tip_fail("Expected to find '${needle}' in one of: ${ARGN}")
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

if(NOT DEFINED TIP_LAYOUT)
  _tip_fail("TIP_LAYOUT is required (fhs|split_debug|split_all)")
endif()
if(NOT DEFINED TIP_REPO_ROOT)
  _tip_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_LAYOUT_TEST_ROOT)
  _tip_fail("TIP_LAYOUT_TEST_ROOT is required")
endif()

string(TOLOWER "${TIP_LAYOUT}" TIP_LAYOUT)
if(NOT TIP_LAYOUT STREQUAL "fhs"
   AND NOT TIP_LAYOUT STREQUAL "split_debug"
   AND NOT TIP_LAYOUT STREQUAL "split_all")
  _tip_fail("Invalid TIP_LAYOUT='${TIP_LAYOUT}'")
endif()

if(NOT DEFINED TIP_LAYOUT_TEST_CONFIG OR TIP_LAYOUT_TEST_CONFIG STREQUAL "")
  set(TIP_LAYOUT_TEST_CONFIG "Debug")
endif()
if(NOT DEFINED TIP_LAYOUT_INSTALL_CONFIG OR TIP_LAYOUT_INSTALL_CONFIG STREQUAL "")
  set(TIP_LAYOUT_INSTALL_CONFIG "${TIP_LAYOUT_TEST_CONFIG}")
endif()
if(NOT DEFINED TIP_LAYOUT_CONSUMER_CONFIG OR TIP_LAYOUT_CONSUMER_CONFIG STREQUAL "")
  set(TIP_LAYOUT_CONSUMER_CONFIG "${TIP_LAYOUT_TEST_CONFIG}")
endif()
string(TOLOWER "${TIP_LAYOUT_INSTALL_CONFIG}" _install_config_lower)
string(TOLOWER "${TIP_LAYOUT_CONSUMER_CONFIG}" _consumer_config_lower)

if(TIP_LAYOUT STREQUAL "fhs")
  set(_layout_suffix "fhs")
elseif(TIP_LAYOUT STREQUAL "split_debug")
  set(_layout_suffix "sd")
elseif(TIP_LAYOUT STREQUAL "split_all")
  set(_layout_suffix "sa")
endif()

function(_tip_config_suffix config out_var)
  string(TOLOWER "${config}" _config_lower)
  if(_config_lower STREQUAL "debug")
    set(_suffix "dbg")
  elseif(_config_lower STREQUAL "release")
    set(_suffix "rel")
  elseif(_config_lower STREQUAL "relwithdebinfo")
    set(_suffix "rwdi")
  elseif(_config_lower STREQUAL "minsizerel")
    set(_suffix "msr")
  else()
    string(REGEX REPLACE "[^a-z0-9]" "" _suffix "${_config_lower}")
  endif()

  set(${out_var}
      "${_suffix}"
      PARENT_SCOPE)
endfunction()

_tip_config_suffix("${TIP_LAYOUT_INSTALL_CONFIG}" _install_config_suffix)
_tip_config_suffix("${TIP_LAYOUT_CONSUMER_CONFIG}" _consumer_config_suffix)

if(WIN32)
  set(_tip_executable_suffix ".exe")
else()
  set(_tip_executable_suffix "${CMAKE_EXECUTABLE_SUFFIX}")
endif()

set(_fixture_source_dir "${TIP_REPO_ROOT}/tests/layout-matrix")
set(_case_root "${TIP_LAYOUT_TEST_ROOT}/${_layout_suffix}-${_install_config_suffix}-${_consumer_config_suffix}")
set(_build_dir "${_case_root}/b")
set(_runtime_prefix "${_case_root}/r")
set(_development_prefix "${_case_root}/d")
set(_full_prefix "${_case_root}/f")

file(REMOVE_RECURSE "${_case_root}")
file(MAKE_DIRECTORY "${_case_root}")

set(_configure_command "${CMAKE_COMMAND}" -S "${_fixture_source_dir}" -B "${_build_dir}" "-DTIP_REPO_ROOT=${TIP_REPO_ROOT}" "-DTIP_LAYOUT=${TIP_LAYOUT}"
                       "-DCMAKE_BUILD_TYPE=${TIP_LAYOUT_INSTALL_CONFIG}")

if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _configure_command -G "${TIP_CMAKE_GENERATOR}")
  if(TIP_CMAKE_GENERATOR MATCHES "Multi-Config|Visual Studio|Xcode")
    list(APPEND _configure_command "-DCMAKE_CONFIGURATION_TYPES=${TIP_LAYOUT_INSTALL_CONFIG}")
  endif()
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

_tip_run_step(NAME "configure" COMMAND ${_configure_command})
_tip_run_step(
  NAME
  "build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_build_dir}"
  --config
  "${TIP_LAYOUT_INSTALL_CONFIG}")
_tip_run_step(
  NAME
  "install-runtime"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_build_dir}"
  --config
  "${TIP_LAYOUT_INSTALL_CONFIG}"
  --prefix
  "${_runtime_prefix}"
  --component
  "Layout")
_tip_run_step(
  NAME
  "install-development"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_build_dir}"
  --config
  "${TIP_LAYOUT_INSTALL_CONFIG}"
  --prefix
  "${_development_prefix}"
  --component
  "Layout_Development")
_tip_run_step(
  NAME
  "install-full"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_build_dir}"
  --config
  "${TIP_LAYOUT_INSTALL_CONFIG}"
  --prefix
  "${_full_prefix}")

set(_cache_file "${_build_dir}/CMakeCache.txt")
_tip_assert_exists("${_cache_file}")

_tip_read_cache_entry("${_cache_file}" "CMAKE_INSTALL_BINDIR" _install_bindir)
_tip_read_cache_entry("${_cache_file}" "CMAKE_INSTALL_LIBDIR" _install_libdir)
_tip_read_cache_entry("${_cache_file}" "CMAKE_INSTALL_INCLUDEDIR" _install_includedir)
_tip_read_cache_entry("${_cache_file}" "CMAKE_INSTALL_DATADIR" _install_datadir)
_tip_read_cache_entry("${_cache_file}" "CMAKE_INSTALL_DATAROOTDIR" _install_datarootdir)

if(_install_datadir STREQUAL "")
  if(_install_datarootdir STREQUAL "")
    set(_install_datadir "share")
  else()
    set(_install_datadir "${_install_datarootdir}")
  endif()
endif()

if(TIP_LAYOUT STREQUAL "fhs")
  set(_layout_prefix "")
elseif(TIP_LAYOUT STREQUAL "split_debug")
  if(_install_config_lower STREQUAL "debug")
    set(_layout_prefix "debug/")
  else()
    set(_layout_prefix "")
  endif()
elseif(TIP_LAYOUT STREQUAL "split_all")
  set(_layout_prefix "${_install_config_lower}/")
endif()

set(_runtime_bindir "${_runtime_prefix}/${_layout_prefix}${_install_bindir}")
set(_runtime_libdir "${_runtime_prefix}/${_layout_prefix}${_install_libdir}")
set(_development_bindir "${_development_prefix}/${_layout_prefix}${_install_bindir}")
set(_development_libdir "${_development_prefix}/${_layout_prefix}${_install_libdir}")
set(_development_cmake_dir "${_development_prefix}/${_install_datadir}/cmake/layout_matrix")
set(_full_bindir "${_full_prefix}/${_layout_prefix}${_install_bindir}")
set(_full_libdir "${_full_prefix}/${_layout_prefix}${_install_libdir}")
set(_full_cmake_dir "${_full_prefix}/${_install_datadir}/cmake/layout_matrix")

set(_runtime_executable_pattern "layout_runner*")
set(_shared_pattern "*layout_dynamic*")
set(_static_pattern "*layout_archive*")

# Runtime component destinations
_tip_assert_glob_exists("${_runtime_bindir}" "${_runtime_executable_pattern}")
if(WIN32)
  _tip_assert_glob_exists("${_runtime_bindir}" "${_shared_pattern}")
else()
  _tip_assert_glob_exists("${_runtime_libdir}" "${_shared_pattern}")
endif()
_tip_assert_not_exists("${_runtime_prefix}/${_install_includedir}/layout/layout.hpp")
_tip_assert_not_exists("${_runtime_prefix}/${_install_datadir}/cmake/layout_matrix")
_tip_assert_glob_absent("${_runtime_libdir}" "${_static_pattern}")

# Development component destinations
_tip_assert_glob_exists("${_development_libdir}" "${_static_pattern}")
_tip_assert_exists("${_development_prefix}/${_install_includedir}/layout/layout.hpp")
_tip_assert_exists("${_development_cmake_dir}/layout_matrixConfig.cmake")
_tip_assert_exists("${_development_cmake_dir}/layout_matrixTargets.cmake")
_tip_assert_exists("${_development_cmake_dir}/layout_matrix-config-version.cmake")
_tip_assert_glob_absent("${_development_bindir}" "${_runtime_executable_pattern}")
_tip_assert_glob_absent("${_development_bindir}" "${_shared_pattern}")

# Generated package metadata paths in exported targets for this layout
file(GLOB _targets_metadata_files "${_development_cmake_dir}/layout_matrixTargets-*.cmake")
if(NOT _targets_metadata_files)
  set(_targets_metadata_files "${_development_cmake_dir}/layout_matrixTargets.cmake")
endif()

foreach(_targets_metadata_file IN LISTS _targets_metadata_files)
  _tip_assert_exists("${_targets_metadata_file}")
endforeach()

set(_import_prefix_literal "\${_IMPORT_PREFIX}")
_tip_assert_any_file_contains("${_import_prefix_literal}/${_layout_prefix}${_install_bindir}/" ${_targets_metadata_files})
_tip_assert_any_file_contains("${_import_prefix_literal}/${_layout_prefix}${_install_libdir}/" ${_targets_metadata_files})

set(_current_list_dir_literal "\${CMAKE_CURRENT_LIST_DIR}")
_tip_assert_file_contains("${_development_cmake_dir}/layout_matrixConfig.cmake" "include(\"${_current_list_dir_literal}/layout_matrixTargets.cmake\")")

set(_installed_runner_candidates
    "${_full_bindir}/layout_runner${_tip_executable_suffix}"
    "${_full_bindir}/layout_runner")
_tip_find_existing_path(_installed_runner ${_installed_runner_candidates})
_tip_run_step(NAME "run-installed-layout-runner" COMMAND "${_installed_runner}")

set(_consumer_dir "${_case_root}/c")
set(_consumer_build_dir "${_consumer_dir}/b")
file(MAKE_DIRECTORY "${_consumer_dir}")

file(
  WRITE
  "${_consumer_dir}/CMakeLists.txt"
  [=[
cmake_minimum_required(VERSION 3.25)
project(layout_matrix_consumer LANGUAGES CXX)

if(DEFINED CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO)
  message(FATAL_ERROR "CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO should be unset before find_package() in this test")
endif()
if(DEFINED CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL)
  message(FATAL_ERROR "CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL should be unset before find_package() in this test")
endif()

find_package(layout_matrix CONFIG REQUIRED)

if(DEFINED CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO)
  message(FATAL_ERROR "find_package(layout_matrix) leaked CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO into the consumer scope")
endif()
if(DEFINED CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL)
  message(FATAL_ERROR "find_package(layout_matrix) leaked CMAKE_MAP_IMPORTED_CONFIG_MINSIZEREL into the consumer scope")
endif()

add_executable(layout_matrix_consumer main.cpp)
target_compile_features(layout_matrix_consumer PRIVATE cxx_std_17)
target_link_libraries(layout_matrix_consumer PRIVATE layout_matrix::layout_archive layout_matrix::layout_dynamic)
]=])

file(
  WRITE
  "${_consumer_dir}/main.cpp"
  [=[
#include "layout/layout.hpp"

int layout_archive_value();

int main() {
  return (layout_archive_value() == 11 && layout_dynamic_value() == 7) ? 0 : 1;
}
]=])

set(_consumer_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_consumer_dir}"
    -B
    "${_consumer_build_dir}"
    "-DCMAKE_PREFIX_PATH=${_full_prefix}"
    "-DCMAKE_BUILD_TYPE=${TIP_LAYOUT_CONSUMER_CONFIG}")
if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
  list(APPEND _consumer_configure_command -G "${TIP_CMAKE_GENERATOR}")
  if(TIP_CMAKE_GENERATOR MATCHES "Multi-Config|Visual Studio|Xcode")
    list(APPEND _consumer_configure_command "-DCMAKE_CONFIGURATION_TYPES=${TIP_LAYOUT_CONSUMER_CONFIG}")
  endif()
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

_tip_run_step(NAME "consumer-configure" COMMAND ${_consumer_configure_command})
_tip_run_step(
  NAME
  "consumer-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_consumer_build_dir}"
  --config
  "${TIP_LAYOUT_CONSUMER_CONFIG}")

set(_consumer_executable_candidates
    "${_consumer_build_dir}/layout_matrix_consumer${_tip_executable_suffix}"
    "${_consumer_build_dir}/${TIP_LAYOUT_CONSUMER_CONFIG}/layout_matrix_consumer${_tip_executable_suffix}"
    "${_consumer_build_dir}/layout_matrix_consumer"
    "${_consumer_build_dir}/${TIP_LAYOUT_CONSUMER_CONFIG}/layout_matrix_consumer")
_tip_find_existing_path(_consumer_executable ${_consumer_executable_candidates})

if(WIN32)
  get_filename_component(_consumer_executable_dir "${_consumer_executable}" DIRECTORY)
  file(GLOB _consumer_runtime_dlls "${_full_bindir}/${_shared_pattern}")
  if(NOT _consumer_runtime_dlls)
    _tip_fail("Expected at least one runtime DLL under '${_full_bindir}' matching '${_shared_pattern}'")
  endif()
  foreach(_consumer_runtime_dll IN LISTS _consumer_runtime_dlls)
    _tip_run_step(
      NAME
      "consumer-copy-runtime-dll"
      COMMAND
      "${CMAKE_COMMAND}"
      -E
      copy_if_different
      "${_consumer_runtime_dll}"
      "${_consumer_executable_dir}")
  endforeach()
  _tip_run_step(NAME "consumer-run" COMMAND "${_consumer_executable}")
else()
  _tip_run_step(NAME "consumer-run" COMMAND "${_consumer_executable}")
endif()

message(STATUS "[layout-matrix] Layout '${TIP_LAYOUT}' assertions passed for install config '${TIP_LAYOUT_INSTALL_CONFIG}' and consumer config '${TIP_LAYOUT_CONSUMER_CONFIG}'.")
