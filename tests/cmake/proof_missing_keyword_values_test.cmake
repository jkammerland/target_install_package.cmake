cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/missing-keyword-values")
file(REMOVE_RECURSE "${_tip_case_root}")
_tip_proof_append_toolchain_args(_tip_toolchain_args)

set(_tip_prelude "cmake_minimum_required(VERSION 3.25)\nproject(Arguments VERSION 1.2.3 LANGUAGES CXX)\ninclude(\"${TIP_REPO_ROOT}/target_install_package.cmake\")\nadd_library(sample INTERFACE)\n")
foreach(_tip_case IN ITEMS namespace_end namespace_before_keyword version_end version_empty postfix_end multi_end)
  if(_tip_case STREQUAL namespace_end)
    set(_tip_args "NAMESPACE")
    set(_tip_expected "Keyword 'NAMESPACE' requires a value")
  elseif(_tip_case STREQUAL namespace_before_keyword)
    set(_tip_args "NAMESPACE VERSION 1.2.3")
    set(_tip_expected "Keyword 'NAMESPACE' requires a value")
  elseif(_tip_case STREQUAL version_end)
    set(_tip_args "VERSION")
    set(_tip_expected "Keyword 'VERSION' requires a value")
  elseif(_tip_case STREQUAL version_empty)
    set(_tip_args "VERSION \"\"")
    set(_tip_expected "Keyword 'VERSION' requires a nonempty value")
  elseif(_tip_case STREQUAL postfix_end)
    set(_tip_args "DEBUG_POSTFIX")
    set(_tip_expected "Keyword 'DEBUG_POSTFIX' requires a value")
  else()
    set(_tip_args "ADDITIONAL_TARGETS")
    set(_tip_expected "Keywords require values")
  endif()
  file(WRITE "${_tip_case_root}/${_tip_case}/CMakeLists.txt" "${_tip_prelude}target_install_package(sample ${_tip_args})\n")
  _tip_proof_expect_failure(
    NAME
    "missing-${_tip_case}"
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${_tip_case_root}/${_tip_case}"
    -B
    "${_tip_case_root}/${_tip_case}-build"
    ${_tip_toolchain_args}
    EXPECT_CONTAINS
    "${_tip_expected}")
endforeach()

# Explicit empty namespace and false-like version zero are values, rather than omitted keywords.
file(WRITE "${_tip_case_root}/valid/CMakeLists.txt" "${_tip_prelude}target_install_package(sample NAMESPACE \"\" VERSION 0 DEBUG_POSTFIX \"\")\n")
_tip_proof_run_step(
  NAME
  explicit-empty-and-zero
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_case_root}/valid"
  -B
  "${_tip_case_root}/valid-build"
  ${_tip_toolchain_args})
_tip_proof_run_step(
  NAME
  explicit-empty-install
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_case_root}/valid-build"
  --prefix
  "${_tip_case_root}/install")
_tip_proof_assert_file_contains("${_tip_case_root}/install/share/cmake/sample/sampleTargets.cmake" "add_library(sample INTERFACE IMPORTED)")
_tip_proof_assert_file_contains("${_tip_case_root}/install/share/cmake/sample/sampleConfigVersion.cmake" "set(PACKAGE_VERSION \"0\")")

# Empty and nonempty namespaces cannot be mixed in the same export.
file(APPEND "${_tip_case_root}/valid/CMakeLists.txt" "add_library(second INTERFACE)\ntarget_install_package(second EXPORT_NAME sample VERSION 0 NAMESPACE Named::)\n")
_tip_proof_expect_failure(
  NAME
  empty-namespace-conflict
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_case_root}/valid"
  -B
  "${_tip_case_root}/namespace-conflict-build"
  ${_tip_toolchain_args}
  EXPECT_CONTAINS
  "Conflicting namespace")
