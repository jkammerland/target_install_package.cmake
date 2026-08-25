cmake_minimum_required(VERSION 4.4)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/multi-component-install")
set(_tip_source_dir "${_tip_case_root}/fixture-src")
set(_tip_build_dir "${_tip_case_root}/fixture-build")
set(_tip_multi_prefix "${_tip_case_root}/custom-multi-prefix")
set(_tip_duplicate_prefix "${_tip_case_root}/duplicate-prefix")
set(_tip_unknown_prefix "${_tip_case_root}/unknown-prefix")
set(_tip_unknown_only_prefix "${_tip_case_root}/unknown-only-prefix")
set(_tip_single_prefix "${_tip_case_root}/single-prefix")
set(_tip_full_prefix "${_tip_case_root}/full-prefix")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/include/multi_component" "${_tip_source_dir}/src")

set(TIP_FIXTURE_REPO_ROOT "${TIP_REPO_ROOT}")
set(_tip_fixture_cmakelists
    [=[
cmake_minimum_required(VERSION 3.25)

project(proof_multi_component_install VERSION 1.0.0 LANGUAGES CXX)

set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include("@TIP_FIXTURE_REPO_ROOT@/cmake/load_target_install_package.cmake")

add_executable(component_runtime src/main.cpp)
target_compile_features(component_runtime PRIVATE cxx_std_17)
target_install_package(
  component_runtime
  EXPORT_NAME MultiComponentPkg
  NAMESPACE MultiComponent::)

add_library(component_sdk INTERFACE)
target_sources(
  component_sdk
  INTERFACE
    FILE_SET HEADERS
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include"
    FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/multi_component/sdk.hpp")
target_install_package(
  component_sdk
  EXPORT_NAME MultiComponentPkg
  NAMESPACE MultiComponent::)

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/unrelated.txt" "unrelated component\n")
install(
  FILES "${CMAKE_CURRENT_BINARY_DIR}/unrelated.txt"
  DESTINATION share/MultiComponentPkg
  COMPONENT Documentation)

# The proof uses this side effect to expose how duplicate component names execute.
install(
  CODE [==[
file(MAKE_DIRECTORY "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/MultiComponentPkg")
file(APPEND "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/MultiComponentPkg/runtime-marker.txt" "installed\n")
]==]
  COMPONENT Runtime)

export_cpack(
  PACKAGE_NAME MultiComponentProof
  PACKAGE_VERSION "${PROJECT_VERSION}"
  GENERATORS TGZ
  COMPONENTS Runtime Development Documentation
  NO_DEFAULT_GENERATORS)
]=])
string(CONFIGURE "${_tip_fixture_cmakelists}" _tip_fixture_cmakelists @ONLY)
file(WRITE "${_tip_source_dir}/CMakeLists.txt" "${_tip_fixture_cmakelists}")
file(WRITE "${_tip_source_dir}/src/main.cpp" "int main() { return 0; }\n")
file(WRITE "${_tip_source_dir}/include/multi_component/sdk.hpp" "#pragma once\n\ninline constexpr int multi_component_value = 1;\n")

_tip_proof_append_toolchain_args(_tip_toolchain_args)
_tip_proof_run_step(
  NAME
  "fixture-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_source_dir}"
  -B
  "${_tip_build_dir}"
  "-DCMAKE_BUILD_TYPE=Release"
  ${_tip_toolchain_args})
_tip_proof_run_step(
  NAME
  "fixture-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_build_dir}"
  --config
  Release)

if(WIN32)
  set(_tip_executable_suffix ".exe")
else()
  set(_tip_executable_suffix "")
endif()

function(_tip_assert_runtime prefix expected)
  set(_tip_runtime_path "${prefix}/bin/component_runtime${_tip_executable_suffix}")
  set(_tip_marker_path "${prefix}/share/MultiComponentPkg/runtime-marker.txt")
  if(expected)
    set(_tip_expected_marker_count 1)
    if(ARGC GREATER 2)
      set(_tip_expected_marker_count "${ARGV2}")
    endif()
    string(REPEAT "installed\n" "${_tip_expected_marker_count}" _tip_expected_marker_content)
    _tip_proof_assert_exists("${_tip_runtime_path}")
    _tip_proof_assert_exists("${_tip_marker_path}")
    file(READ "${_tip_marker_path}" _tip_marker_content)
    if(NOT _tip_marker_content STREQUAL _tip_expected_marker_content)
      _tip_proof_fail("Expected Runtime install marker ${_tip_expected_marker_count} time(s) in '${_tip_marker_path}', got '${_tip_marker_content}'")
    endif()
  else()
    _tip_proof_assert_not_exists("${_tip_runtime_path}")
    _tip_proof_assert_not_exists("${_tip_marker_path}")
  endif()
endfunction()

function(_tip_assert_development prefix expected)
  set(_tip_header_path "${prefix}/include/multi_component/sdk.hpp")
  set(_tip_config_path "${prefix}/share/cmake/MultiComponentPkg/MultiComponentPkgConfig.cmake")
  set(_tip_targets_path "${prefix}/share/cmake/MultiComponentPkg/MultiComponentPkgTargets.cmake")
  if(expected)
    _tip_proof_assert_exists("${_tip_header_path}")
    _tip_proof_assert_exists("${_tip_config_path}")
    _tip_proof_assert_exists("${_tip_targets_path}")
  else()
    _tip_proof_assert_not_exists("${_tip_header_path}")
    _tip_proof_assert_not_exists("${_tip_config_path}")
    _tip_proof_assert_not_exists("${_tip_targets_path}")
  endif()
endfunction()

function(_tip_assert_documentation prefix expected)
  set(_tip_documentation_path "${prefix}/share/MultiComponentPkg/unrelated.txt")
  if(expected)
    _tip_proof_assert_exists("${_tip_documentation_path}")
  else()
    _tip_proof_assert_not_exists("${_tip_documentation_path}")
  endif()
endfunction()

set(_tip_cpack_config "${_tip_build_dir}/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_cpack_config}" "CPACK_COMPONENT_DEVELOPMENT_DEPENDS \"Runtime\"")

# CMake 4.4 accepts multiple values after one --component option.
_tip_proof_run_step(
  NAME
  "multi-component-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build_dir}"
  --config
  Release
  --component
  Runtime
  Development
  --prefix
  "${_tip_multi_prefix}")
_tip_assert_runtime("${_tip_multi_prefix}" TRUE)
_tip_assert_development("${_tip_multi_prefix}" TRUE)
_tip_assert_documentation("${_tip_multi_prefix}" FALSE)

# Repeated options and duplicate names are accepted; each occurrence executes its component.
_tip_proof_run_step(
  NAME
  "duplicate-component-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build_dir}"
  --config
  Release
  --component
  Runtime
  Runtime
  --component
  Development
  Development
  --prefix
  "${_tip_duplicate_prefix}")
_tip_assert_runtime("${_tip_duplicate_prefix}" TRUE 2)
_tip_assert_development("${_tip_duplicate_prefix}" TRUE)
_tip_assert_documentation("${_tip_duplicate_prefix}" FALSE)

# Unknown names are ignored without hiding known components or selecting anything else.
_tip_proof_run_step(
  NAME
  "known-and-unknown-component-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build_dir}"
  --config
  Release
  --component
  Runtime
  UnknownComponent
  --prefix
  "${_tip_unknown_prefix}")
_tip_assert_runtime("${_tip_unknown_prefix}" TRUE)
_tip_assert_development("${_tip_unknown_prefix}" FALSE)
_tip_assert_documentation("${_tip_unknown_prefix}" FALSE)

_tip_proof_run_step(
  NAME
  "unknown-only-component-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build_dir}"
  --config
  Release
  --component
  UnknownComponent
  --prefix
  "${_tip_unknown_only_prefix}")
_tip_assert_runtime("${_tip_unknown_only_prefix}" FALSE)
_tip_assert_development("${_tip_unknown_only_prefix}" FALSE)
_tip_assert_documentation("${_tip_unknown_only_prefix}" FALSE)

# Raw installs do not follow CPack component dependencies.
_tip_proof_run_step(
  NAME
  "single-development-component-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build_dir}"
  --config
  Release
  --component
  Development
  --prefix
  "${_tip_single_prefix}")
_tip_assert_runtime("${_tip_single_prefix}" FALSE)
_tip_assert_development("${_tip_single_prefix}" TRUE)
_tip_assert_documentation("${_tip_single_prefix}" FALSE)

# Omitting --component retains the existing full-install path.
_tip_proof_run_step(
  NAME
  "full-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build_dir}"
  --config
  Release
  --prefix
  "${_tip_full_prefix}")
_tip_assert_runtime("${_tip_full_prefix}" TRUE)
_tip_assert_development("${_tip_full_prefix}" TRUE)
_tip_assert_documentation("${_tip_full_prefix}" TRUE)

message(STATUS "[proof] CMake 4.4 multi-component install proof passed.")
