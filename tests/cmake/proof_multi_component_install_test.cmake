CMAKE_MINIMUM_REQUIRED(VERSION 4.4)

INCLUDE("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

IF(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
ENDIF()
IF(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
ENDIF()

SET(_tip_case_root "${TIP_PROOF_TEST_ROOT}/multi-component-install")
SET(_tip_source_dir "${_tip_case_root}/fixture-src")
SET(_tip_build_dir "${_tip_case_root}/fixture-build")
SET(_tip_multi_prefix "${_tip_case_root}/custom-multi-prefix")
SET(_tip_duplicate_prefix "${_tip_case_root}/duplicate-prefix")
SET(_tip_unknown_prefix "${_tip_case_root}/unknown-prefix")
SET(_tip_unknown_only_prefix "${_tip_case_root}/unknown-only-prefix")
SET(_tip_single_prefix "${_tip_case_root}/single-prefix")
SET(_tip_status_prefix "${_tip_case_root}/status-prefix")
SET(_tip_full_prefix "${_tip_case_root}/full-prefix")

FILE(REMOVE_RECURSE "${_tip_case_root}")
FILE(MAKE_DIRECTORY "${_tip_source_dir}/include/multi_component" "${_tip_source_dir}/src")

SET(TIP_FIXTURE_REPO_ROOT "${TIP_REPO_ROOT}")
SET(_tip_fixture_cmakelists
    [=[
CMAKE_MINIMUM_REQUIRED(VERSION 3.25)

PROJECT(proof_multi_component_install VERSION 1.0.0 LANGUAGES CXX)

SET(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
INCLUDE("@TIP_FIXTURE_REPO_ROOT@/cmake/load_target_install_package.cmake")

ADD_EXECUTABLE(component_runtime src/main.cpp)
TARGET_COMPILE_FEATURES(component_runtime PRIVATE cxx_std_17)
target_install_package(
  component_runtime
  EXPORT_NAME MultiComponentPkg
  NAMESPACE MultiComponent::)

ADD_LIBRARY(component_sdk INTERFACE)
TARGET_SOURCES(
  component_sdk
  INTERFACE
    FILE_SET HEADERS
    BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/include"
    FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/multi_component/sdk.hpp")
target_install_package(
  component_sdk
  EXPORT_NAME MultiComponentPkg
  NAMESPACE MultiComponent::)

FILE(WRITE "${CMAKE_CURRENT_BINARY_DIR}/unrelated.txt" "unrelated component\n")
INSTALL(
  FILES "${CMAKE_CURRENT_BINARY_DIR}/unrelated.txt"
  DESTINATION share/MultiComponentPkg
  COMPONENT Documentation)

FILE(WRITE "${CMAKE_CURRENT_BINARY_DIR}/excluded.txt" "excluded from full installs\n")
INSTALL(
  FILES "${CMAKE_CURRENT_BINARY_DIR}/excluded.txt"
  DESTINATION share/MultiComponentPkg
  COMPONENT ExplicitOnly
  EXCLUDE_FROM_ALL)

# The proof uses this side effect to expose how duplicate component names execute.
INSTALL(
  CODE [==[
FILE(MAKE_DIRECTORY "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/MultiComponentPkg")
FILE(APPEND "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/MultiComponentPkg/runtime-marker.txt" "installed\n")
]==]
  COMPONENT Runtime)

# CMake 4.4.0 through 4.4.2 overwrite this exit status when the later component
# succeeds. Keep these rules out of the otherwise successful full-install case.
INSTALL(
  CODE [==[
FILE(MAKE_DIRECTORY "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/MultiComponentPkg")
FILE(WRITE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/MultiComponentPkg/status-failure-started.txt" "started\n")
CMAKE_LANGUAGE(EXIT 23)
]==]
  COMPONENT StatusFailure
  EXCLUDE_FROM_ALL)
INSTALL(
  CODE [==[
FILE(MAKE_DIRECTORY "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/MultiComponentPkg")
FILE(WRITE "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/share/MultiComponentPkg/status-later-succeeded.txt" "succeeded\n")
]==]
  COMPONENT StatusLaterSuccess
  EXCLUDE_FROM_ALL)

export_cpack(
  PACKAGE_NAME MultiComponentProof
  PACKAGE_VERSION "${PROJECT_VERSION}"
  GENERATORS TGZ
  COMPONENTS Runtime Development Documentation
  NO_DEFAULT_GENERATORS)
]=])
STRING(CONFIGURE "${_tip_fixture_cmakelists}" _tip_fixture_cmakelists @ONLY)
FILE(WRITE "${_tip_source_dir}/CMakeLists.txt" "${_tip_fixture_cmakelists}")
FILE(WRITE "${_tip_source_dir}/src/main.cpp" "int main() { return 0; }\n")
FILE(WRITE "${_tip_source_dir}/include/multi_component/sdk.hpp" "#pragma once\n\ninline constexpr int multi_component_value = 1;\n")

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

IF(WIN32)
  SET(_tip_executable_suffix ".exe")
ELSE()
  SET(_tip_executable_suffix "")
ENDIF()

FUNCTION(_tip_assert_runtime prefix expected)
  SET(_tip_runtime_path "${prefix}/bin/component_runtime${_tip_executable_suffix}")
  SET(_tip_marker_path "${prefix}/share/MultiComponentPkg/runtime-marker.txt")
  IF(expected)
    SET(_tip_expected_marker_count 1)
    IF(ARGC GREATER 2)
      SET(_tip_expected_marker_count "${ARGV2}")
    ENDIF()
    STRING(REPEAT "installed\n" "${_tip_expected_marker_count}" _tip_expected_marker_content)
    _tip_proof_assert_exists("${_tip_runtime_path}")
    _tip_proof_assert_exists("${_tip_marker_path}")
    FILE(READ "${_tip_marker_path}" _tip_marker_content)
    IF(NOT _tip_marker_content STREQUAL _tip_expected_marker_content)
      _tip_proof_fail("Expected Runtime install marker ${_tip_expected_marker_count} time(s) in '${_tip_marker_path}', got '${_tip_marker_content}'")
    ENDIF()
  ELSE()
    _tip_proof_assert_not_exists("${_tip_runtime_path}")
    _tip_proof_assert_not_exists("${_tip_marker_path}")
  ENDIF()
ENDFUNCTION()

FUNCTION(_tip_assert_development prefix expected)
  SET(_tip_header_path "${prefix}/include/multi_component/sdk.hpp")
  SET(_tip_config_path "${prefix}/share/cmake/MultiComponentPkg/MultiComponentPkgConfig.cmake")
  SET(_tip_targets_path "${prefix}/share/cmake/MultiComponentPkg/MultiComponentPkgTargets.cmake")
  IF(expected)
    _tip_proof_assert_exists("${_tip_header_path}")
    _tip_proof_assert_exists("${_tip_config_path}")
    _tip_proof_assert_exists("${_tip_targets_path}")
  ELSE()
    _tip_proof_assert_not_exists("${_tip_header_path}")
    _tip_proof_assert_not_exists("${_tip_config_path}")
    _tip_proof_assert_not_exists("${_tip_targets_path}")
  ENDIF()
ENDFUNCTION()

FUNCTION(_tip_assert_documentation prefix expected)
  SET(_tip_documentation_path "${prefix}/share/MultiComponentPkg/unrelated.txt")
  IF(expected)
    _tip_proof_assert_exists("${_tip_documentation_path}")
  ELSE()
    _tip_proof_assert_not_exists("${_tip_documentation_path}")
  ENDIF()
ENDFUNCTION()

FUNCTION(_tip_assert_explicit_only prefix expected)
  SET(_tip_explicit_only_path "${prefix}/share/MultiComponentPkg/excluded.txt")
  IF(expected)
    _tip_proof_assert_exists("${_tip_explicit_only_path}")
  ELSE()
    _tip_proof_assert_not_exists("${_tip_explicit_only_path}")
  ENDIF()
ENDFUNCTION()

SET(_tip_cpack_config "${_tip_build_dir}/CPackConfig.cmake")
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

# Released CMake 4.4.0 through 4.4.2 mask an earlier serial component failure
# when a later component succeeds. Future releases may contain the upstream fix,
# so only known affected versions are required to reproduce the bad exit status.
EXECUTE_PROCESS(
  COMMAND
    "${CMAKE_COMMAND}" --install "${_tip_build_dir}" --config Release --component StatusFailure StatusLaterSuccess --prefix "${_tip_status_prefix}"
  RESULT_VARIABLE _tip_status_result
  OUTPUT_VARIABLE _tip_status_stdout
  ERROR_VARIABLE _tip_status_stderr)
SET(_tip_status_failure_marker "${_tip_status_prefix}/share/MultiComponentPkg/status-failure-started.txt")
SET(_tip_status_later_marker "${_tip_status_prefix}/share/MultiComponentPkg/status-later-succeeded.txt")
_tip_proof_assert_exists("${_tip_status_failure_marker}")
IF(CMAKE_VERSION VERSION_GREATER_EQUAL "4.4.0" AND CMAKE_VERSION VERSION_LESS_EQUAL "4.4.2")
  IF(NOT "${_tip_status_result}" STREQUAL "0")
    MESSAGE(STATUS "[proof][stdout]\n${_tip_status_stdout}")
    MESSAGE(STATUS "[proof][stderr]\n${_tip_status_stderr}")
    _tip_proof_fail("Expected released CMake ${CMAKE_VERSION} to mask the earlier component failure, got exit code ${_tip_status_result}")
  ENDIF()
  _tip_proof_assert_exists("${_tip_status_later_marker}")
  MESSAGE(STATUS "[proof] Confirmed CMake ${CMAKE_VERSION} masks the earlier serial component failure.")
ELSEIF("${_tip_status_result}" STREQUAL "0")
  _tip_proof_assert_exists("${_tip_status_later_marker}")
  MESSAGE(STATUS "[proof] CMake ${CMAKE_VERSION} still masks the earlier serial component failure.")
ELSE()
  _tip_proof_assert_not_exists("${_tip_status_later_marker}")
  MESSAGE(STATUS "[proof] CMake ${CMAKE_VERSION} propagates the earlier serial component failure.")
ENDIF()

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
_tip_assert_explicit_only("${_tip_full_prefix}" FALSE)
_tip_proof_assert_not_exists("${_tip_full_prefix}/share/MultiComponentPkg/status-failure-started.txt")
_tip_proof_assert_not_exists("${_tip_full_prefix}/share/MultiComponentPkg/status-later-succeeded.txt")

MESSAGE(STATUS "[proof] CMake 4.4 multi-component install proof passed.")
