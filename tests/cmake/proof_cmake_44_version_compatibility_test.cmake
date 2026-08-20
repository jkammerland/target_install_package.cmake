cmake_minimum_required(VERSION 4.4)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cmake-44-version-compatibility")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_case_root}/fixture-build")
set(_tip_install_prefix "${_tip_case_root}/fixture-install")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.4)\n"
  "project(proof_cmake_44_versions VERSION 1.2.3.4 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "function(add_version_package name version compatibility)\n"
  "  add_library(\${name} INTERFACE)\n"
  "  target_install_package(\${name} EXPORT_NAME \${name}_pkg VERSION \${version} COMPATIBILITY \${compatibility} \${ARGN})\n"
  "endfunction()\n"
  "function(assert_cps_floor compatibility version expected)\n"
  "  _tip_derive_cps_compat_version(actual \"\${version}\" \"\${compatibility}\" simple)\n"
  "  if(NOT \"\${actual}\" STREQUAL \"\${expected}\")\n"
  "    message(FATAL_ERROR \"CPS floor for \${compatibility} \${version}: expected '\${expected}', got '\${actual}'\")\n"
  "  endif()\n"
  "endfunction()\n"
  "assert_cps_floor(SemanticVersion 1.2.3 1.0.0)\n"
  "assert_cps_floor(SemanticVersion 0.2.3 0.2.0)\n"
  "assert_cps_floor(SameFullVersion 1.2.3 \"\")\n"
  "assert_cps_floor(SamePatchVersion 1.2.3.4 \"\")\n"
  "add_version_package(same_patch 1.2.3.4 SamePatchVersion)\n"
  "add_version_package(same_full 1.2.3 SameFullVersion)\n"
  "add_version_package(semantic_stable 1.2.3 SemanticVersion)\n"
  "add_version_package(semantic_zero 0.2.3 SemanticVersion)\n"
  "add_version_package(arch_independent 1.2.3 SameMajorVersion ARCH_INDEPENDENT)\n"
  "add_version_package(arch_dependent 1.2.3 SameMajorVersion)\n"
  "add_version_package(exact_deprecated 1.2.3 ExactVersion)\n")

execute_process(
  COMMAND "${CMAKE_COMMAND}" -S "${_tip_fixture_source_dir}" -B "${_tip_fixture_build_dir}" ${_tip_toolchain_args}
  RESULT_VARIABLE _tip_configure_result
  OUTPUT_VARIABLE _tip_configure_stdout
  ERROR_VARIABLE _tip_configure_stderr)
if(NOT _tip_configure_result EQUAL 0)
  message(STATUS "[proof][stdout]\n${_tip_configure_stdout}")
  message(STATUS "[proof][stderr]\n${_tip_configure_stderr}")
  _tip_proof_fail("CMake 4.4 version fixture configure failed")
endif()
set(_tip_configure_output "${_tip_configure_stdout}\n${_tip_configure_stderr}")
string(FIND "${_tip_configure_output}" "COMPATIBILITY ExactVersion is deprecated by CMake 4.4" _tip_deprecation_index)
if(_tip_deprecation_index EQUAL -1)
  _tip_proof_fail("Expected ExactVersion deprecation message during configure")
endif()

_tip_proof_run_step(
  NAME
  "fixture-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_fixture_build_dir}"
  --prefix
  "${_tip_install_prefix}")

function(_tip_check_find name package requirement expect_success)
  set(_tip_source_dir "${_tip_case_root}/consumer-${name}-src")
  set(_tip_build_dir "${_tip_case_root}/consumer-${name}-build")
  file(MAKE_DIRECTORY "${_tip_source_dir}")
  file(WRITE "${_tip_source_dir}/CMakeLists.txt" "cmake_minimum_required(VERSION 4.4)\n" "project(consumer_${name} LANGUAGES NONE)\n"
                                                 "find_package(${package} ${requirement} CONFIG REQUIRED PATHS \"${_tip_install_prefix}\" NO_DEFAULT_PATH)\n")

  set(_tip_command "${CMAKE_COMMAND}" -S "${_tip_source_dir}" -B "${_tip_build_dir}")
  if(expect_success)
    _tip_proof_run_step(NAME "find-${name}" COMMAND ${_tip_command})
  else()
    _tip_proof_expect_failure(NAME "find-${name}" COMMAND ${_tip_command})
  endif()
endfunction()

_tip_check_find(same-patch-tweak same_patch_pkg 1.2.3.5 TRUE)
_tip_check_find(same-patch-change same_patch_pkg 1.2.4 FALSE)
_tip_check_find(same-full-count same_full_pkg 1.2.3.0 FALSE)
_tip_check_find(same-full-exact same_full_pkg 1.2.3 TRUE)
_tip_check_find(semantic-stable semantic_stable_pkg 1.0 TRUE)
_tip_check_find(semantic-stable-major semantic_stable_pkg 2.0 FALSE)
_tip_check_find(semantic-zero semantic_zero_pkg 0.2.0 TRUE)
_tip_check_find(semantic-zero-minor semantic_zero_pkg 0.1 FALSE)
_tip_check_find(semantic-range semantic_stable_pkg "1.0...<2.0" TRUE)

function(_tip_check_architecture package expect_unsuitable)
  set(PACKAGE_FIND_VERSION 1.2.3)
  set(PACKAGE_FIND_VERSION_MAJOR 1)
  set(PACKAGE_FIND_VERSION_MINOR 2)
  set(PACKAGE_FIND_VERSION_PATCH 3)
  set(PACKAGE_FIND_VERSION_TWEAK 0)
  set(PACKAGE_FIND_VERSION_COUNT 3)
  set(CMAKE_SIZEOF_VOID_P 4)
  unset(PACKAGE_VERSION_UNSUITABLE)
  include("${_tip_install_prefix}/share/cmake/${package}/${package}ConfigVersion.cmake")
  if(expect_unsuitable AND NOT PACKAGE_VERSION_UNSUITABLE)
    _tip_proof_fail("Expected ${package} to reject the simulated architecture mismatch")
  elseif(NOT expect_unsuitable AND PACKAGE_VERSION_UNSUITABLE)
    _tip_proof_fail("Expected ${package} to ignore the simulated architecture mismatch")
  endif()
endfunction()

_tip_check_architecture(arch_dependent_pkg TRUE)
_tip_check_architecture(arch_independent_pkg FALSE)

message(STATUS "[proof] CMake 4.4 version compatibility proof passed.")
