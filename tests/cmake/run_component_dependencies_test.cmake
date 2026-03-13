cmake_minimum_required(VERSION 3.25)

function(_tip_fail text)
  message(FATAL_ERROR "[component-deps] ${text}")
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
    message(STATUS "[component-deps] Step '${ARG_NAME}' failed.")
    if(NOT _stdout STREQUAL "")
      message(STATUS "[component-deps][stdout]\n${_stdout}")
    endif()
    if(NOT _stderr STREQUAL "")
      message(STATUS "[component-deps][stderr]\n${_stderr}")
    endif()
    _tip_fail("Step '${ARG_NAME}' exited with code ${_result}")
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

function(_tip_write_fake_package prefix package_name)
  set(_tip_package_dir "${prefix}/share/cmake/${package_name}")
  file(MAKE_DIRECTORY "${_tip_package_dir}")

  file(
    WRITE
    "${_tip_package_dir}/${package_name}Config.cmake"
    "set(${package_name}_FOUND TRUE)\nif(NOT TARGET ${package_name}::${package_name})\n  add_library(${package_name}::${package_name} INTERFACE IMPORTED)\nendif()\n")

  file(
    WRITE
    "${_tip_package_dir}/${package_name}ConfigVersion.cmake"
    "set(PACKAGE_VERSION \"1.0.0\")\nset(PACKAGE_VERSION_COMPATIBLE TRUE)\nset(PACKAGE_VERSION_EXACT TRUE)\n")
endfunction()

function(_tip_run_consumer_case)
  set(options "")
  set(oneValueArgs NAME)
  set(multiValueArgs COMPONENTS EXPECTED_DEPS UNEXPECTED_DEPS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_NAME)
    _tip_fail("_tip_run_consumer_case requires NAME")
  endif()
  if(NOT ARG_COMPONENTS)
    _tip_fail("_tip_run_consumer_case requires at least one component")
  endif()

  set(_case_dir "${_consumer_root}/${ARG_NAME}")
  set(_case_build_dir "${_case_dir}/build")
  file(MAKE_DIRECTORY "${_case_dir}")

  set(_consumer_cmakelists "cmake_minimum_required(VERSION 3.25)\n")
  string(APPEND _consumer_cmakelists "project(component_deps_consumer_${ARG_NAME} LANGUAGES CXX)\n\n")
  string(APPEND _consumer_cmakelists "find_package(component_deps_fixture CONFIG REQUIRED COMPONENTS")
  foreach(component IN LISTS ARG_COMPONENTS)
    string(APPEND _consumer_cmakelists " \"${component}\"")
  endforeach()
  string(APPEND _consumer_cmakelists ")\n\n")

  foreach(dep IN LISTS ARG_EXPECTED_DEPS)
    string(APPEND _consumer_cmakelists "if(NOT ${dep}_FOUND)\n")
    string(APPEND _consumer_cmakelists "  message(FATAL_ERROR \"${dep} was not loaded for case ${ARG_NAME}\")\n")
    string(APPEND _consumer_cmakelists "endif()\n")
  endforeach()

  foreach(dep IN LISTS ARG_UNEXPECTED_DEPS)
    string(APPEND _consumer_cmakelists "if(${dep}_FOUND)\n")
    string(APPEND _consumer_cmakelists "  message(FATAL_ERROR \"${dep} was unexpectedly loaded for case ${ARG_NAME}\")\n")
    string(APPEND _consumer_cmakelists "endif()\n")
  endforeach()

  string(
    APPEND
    _consumer_cmakelists
    "\nadd_executable(component_deps_consumer main.cpp)\n"
    "target_compile_features(component_deps_consumer PRIVATE cxx_std_17)\n"
    "target_link_libraries(component_deps_consumer PRIVATE ComponentDeps::component_base ComponentDeps::component_tools)\n")

  file(WRITE "${_case_dir}/CMakeLists.txt" "${_consumer_cmakelists}")

  file(
    WRITE
    "${_case_dir}/main.cpp"
    [=[
int component_base_value();
int component_tools_value();

int main() {
  return (component_base_value() == 1 && component_tools_value() == 2) ? 0 : 1;
}
]=])

  set(_consumer_configure_command
      "${CMAKE_COMMAND}"
      -S
      "${_case_dir}"
      -B
      "${_case_build_dir}"
      "-DCMAKE_PREFIX_PATH=${_install_prefix}"
      "-DDepA_DIR=${_deps_prefix}/share/cmake/DepA"
      "-DDepB_DIR=${_deps_prefix}/share/cmake/DepB"
      "-DDepC_DIR=${_deps_prefix}/share/cmake/DepC"
      "-DDepD_DIR=${_deps_prefix}/share/cmake/DepD")

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

  _tip_run_step(NAME "consumer-configure-${ARG_NAME}" COMMAND ${_consumer_configure_command})
  _tip_run_step(
    NAME
    "consumer-build-${ARG_NAME}"
    COMMAND
    "${CMAKE_COMMAND}"
    --build
    "${_case_build_dir}"
    --config
    "${TIP_COMPONENT_TEST_CONFIG}")

  set(_consumer_executable_candidates
      "${_case_build_dir}/component_deps_consumer${_tip_executable_suffix}"
      "${_case_build_dir}/${TIP_COMPONENT_TEST_CONFIG}/component_deps_consumer${_tip_executable_suffix}"
      "${_case_build_dir}/component_deps_consumer"
      "${_case_build_dir}/${TIP_COMPONENT_TEST_CONFIG}/component_deps_consumer")
  _tip_find_existing_path(_consumer_executable ${_consumer_executable_candidates})
  _tip_run_step(NAME "consumer-run-${ARG_NAME}" COMMAND "${_consumer_executable}")
endfunction()

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_fail("TIP_REPO_ROOT is required")
endif()

if(NOT DEFINED TIP_COMPONENT_TEST_ROOT)
  _tip_fail("TIP_COMPONENT_TEST_ROOT is required")
endif()

if(NOT DEFINED TIP_COMPONENT_TEST_CONFIG OR TIP_COMPONENT_TEST_CONFIG STREQUAL "")
  set(TIP_COMPONENT_TEST_CONFIG "Debug")
endif()

if(WIN32)
  set(_tip_executable_suffix ".exe")
else()
  set(_tip_executable_suffix "${CMAKE_EXECUTABLE_SUFFIX}")
endif()

set(_fixture_source_dir "${TIP_REPO_ROOT}/tests/component-dependencies")
set(_case_root "${TIP_COMPONENT_TEST_ROOT}")
set(_build_dir "${_case_root}/fixture-build")
set(_install_prefix "${_case_root}/fixture-install")
set(_deps_prefix "${_case_root}/deps-prefix")
set(_consumer_root "${_case_root}/consumer")

file(REMOVE_RECURSE "${_case_root}")
file(MAKE_DIRECTORY "${_case_root}")

set(_configure_command
    "${CMAKE_COMMAND}"
    -S
    "${_fixture_source_dir}"
    -B
    "${_build_dir}"
    "-DTIP_REPO_ROOT=${TIP_REPO_ROOT}"
    "-DCMAKE_BUILD_TYPE=${TIP_COMPONENT_TEST_CONFIG}")

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

_tip_run_step(NAME "fixture-configure" COMMAND ${_configure_command})
_tip_run_step(
  NAME
  "fixture-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_build_dir}"
  --config
  "${TIP_COMPONENT_TEST_CONFIG}")
_tip_run_step(
  NAME
  "fixture-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_build_dir}"
  --config
  "${TIP_COMPONENT_TEST_CONFIG}"
  --prefix
  "${_install_prefix}")

_tip_write_fake_package("${_deps_prefix}" "DepA")
_tip_write_fake_package("${_deps_prefix}" "DepB")
_tip_write_fake_package("${_deps_prefix}" "DepC")
_tip_write_fake_package("${_deps_prefix}" "DepD")

file(MAKE_DIRECTORY "${_consumer_root}")

_tip_run_consumer_case(NAME graphics COMPONENTS graphics EXPECTED_DEPS DepA DepB UNEXPECTED_DEPS DepC DepD)
_tip_run_consumer_case(NAME ui_dash COMPONENTS ui-core EXPECTED_DEPS DepC UNEXPECTED_DEPS DepA DepB DepD)
_tip_run_consumer_case(NAME ui_underscore COMPONENTS ui_core EXPECTED_DEPS DepD UNEXPECTED_DEPS DepA DepB DepC)

message(STATUS "[component-deps] Component dependency assertions passed.")
