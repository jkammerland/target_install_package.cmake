cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT POLICY CMP0174)
  _tip_proof_fail("proof_policy_scope requires CMake 3.31 or newer and should not be registered on older CMake versions")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/policy-scope")
file(REMOVE_RECURSE "${_tip_case_root}")
_tip_proof_append_toolchain_args(_tip_toolchain_args)

# Checks are inlined at directory scope because macros and functions apply the policies recorded at their definition.
set(_tip_check_template
    [=[
foreach(_policy IN ITEMS CMP0174 CMP0177)
  cmake_policy(GET ${_policy} _policy_value)
  if(NOT _policy_value STREQUAL "")
    list(APPEND _policy_changes "${_policy} became '${_policy_value}' after @STAGE@")
  endif()
endforeach()
]=])
string(REPLACE "@STAGE@" "loading target_install_package" _tip_check_load "${_tip_check_template}")
string(REPLACE "@STAGE@" "target_install_package()" _tip_check_register "${_tip_check_template}")
string(REPLACE "@STAGE@" "export_cpack()" _tip_check_cpack "${_tip_check_template}")

# The fixture's minimum predates CMP0174 and CMP0177, so both start unset. Loading the module, registering a
# package, and configuring CPack must leave them unset in the caller's directory and in functions it defines later.
set(_tip_fixture
    [=[
cmake_minimum_required(VERSION 3.25)
project(PolicyScope VERSION 1.0.0 LANGUAGES CXX)
set(_policy_changes "")

include("@TIP_REPO_ROOT@/cmake/load_target_install_package.cmake")
@_tip_check_load@
file(WRITE "${CMAKE_BINARY_DIR}/policy_scope.cpp" "int policy_scope_value() { return 1; }\n")
add_library(policy_scope STATIC "${CMAKE_BINARY_DIR}/policy_scope.cpp")
target_install_package(policy_scope)
@_tip_check_register@
export_cpack(PACKAGE_NAME PolicyScope GENERATORS TGZ)
@_tip_check_cpack@
# With CMP0174 unset, an explicit empty one-value argument remains undefined in caller-defined functions.
function(parse_explicit_empty_value)
  cmake_parse_arguments(PARSE_ARGV 0 ARG "" "VALUE" "")
  if(DEFINED ARG_VALUE)
    set(_policy_changes "${_policy_changes};function defined after registration parsed VALUE \"\" with CMP0174 NEW" PARENT_SCOPE)
  endif()
endfunction()
parse_explicit_empty_value(VALUE "")

if(_policy_changes)
  list(JOIN _policy_changes "\n  " _policy_report)
  message(FATAL_ERROR "Caller policy settings changed:\n  ${_policy_report}")
endif()
]=])
string(CONFIGURE "${_tip_fixture}" _tip_fixture @ONLY)
file(WRITE "${_tip_case_root}/source/CMakeLists.txt" "${_tip_fixture}")

_tip_proof_run_step(
  NAME
  "policy-scope-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_case_root}/source"
  -B
  "${_tip_case_root}/build"
  ${_tip_toolchain_args})

message(STATUS "[proof] Policy scope proof passed.")
