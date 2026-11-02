cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/debug-postfix")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_case_root}/source")
_tip_proof_append_toolchain_args(_tip_toolchain_args)

set(_tip_project
    [=[
cmake_minimum_required(VERSION 3.25)
project(Postfix VERSION 1.0.0 LANGUAGES CXX)
include("@TIP_REPO_ROOT@/target_install_package.cmake")
set(CMAKE_INSTALL_LIBDIR lib)
foreach(name IN ITEMS fallback own late explicit empty false zero preempty)
  add_library(${name} STATIC value.cpp)
endforeach()
set_property(TARGET own PROPERTY DEBUG_POSTFIX _own)
set_property(TARGET preempty PROPERTY DEBUG_POSTFIX "")
set(CMAKE_DEBUG_POSTFIX _global)
add_library(inherited STATIC value.cpp)
unset(CMAKE_DEBUG_POSTFIX)

# Grouping must not impose one target's postfix on its neighbors.
target_install_package(fallback EXPORT_NAME Postfix)
target_install_package(own EXPORT_NAME Postfix ADDITIONAL_TARGETS inherited)
target_install_package(late EXPORT_NAME Postfix)
set_property(TARGET late PROPERTY DEBUG_POSTFIX _late)
target_install_package(explicit EXPORT_NAME Postfix DEBUG_POSTFIX _chosen)
set_property(TARGET explicit PROPERTY DEBUG_POSTFIX _ignored)
target_install_package(empty EXPORT_NAME Postfix DEBUG_POSTFIX "")
target_install_package(false EXPORT_NAME Postfix DEBUG_POSTFIX OFF)
target_prepare_package(zero EXPORT_NAME Postfix DEBUG_POSTFIX 0)
target_install_package(preempty EXPORT_NAME Postfix)
file(WRITE "${CMAKE_BINARY_DIR}/platform.cmake" "set(PREFIX ${CMAKE_STATIC_LIBRARY_PREFIX})\nset(SUFFIX ${CMAKE_STATIC_LIBRARY_SUFFIX})\n")
]=])
string(CONFIGURE "${_tip_project}" _tip_project @ONLY)
file(WRITE "${_tip_case_root}/source/CMakeLists.txt" "${_tip_project}")
file(WRITE "${_tip_case_root}/source/value.cpp" "int value() { return 42; }\n")
_tip_proof_run_step(
  NAME
  postfix-configure
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_case_root}/source"
  -B
  "${_tip_case_root}/build"
  -DCMAKE_BUILD_TYPE=Debug
  ${_tip_toolchain_args})
_tip_proof_run_step(
  NAME
  postfix-build
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_case_root}/build"
  --config
  Debug)
_tip_proof_run_step(
  NAME
  postfix-install
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_case_root}/build"
  --config
  Debug
  --prefix
  "${_tip_case_root}/install")
include("${_tip_case_root}/build/platform.cmake")
foreach(
  _tip_expected IN
  ITEMS fallbackd
        own_own
        late_late
        explicit_chosen
        empty
        falseOFF
        zero0
        preempty
        inherited_global)
  _tip_proof_assert_exists("${_tip_case_root}/install/lib/${PREFIX}${_tip_expected}${SUFFIX}")
  _tip_proof_assert_file_contains("${_tip_case_root}/install/share/cmake/Postfix/PostfixTargets-debug.cmake" "${PREFIX}${_tip_expected}${SUFFIX}")
endforeach()
foreach(
  _tip_wrong IN
  ITEMS emptyd
        falsed
        zerod
        preemptyd
        ownd
        lated
        explicit_ignored
        inheritedd)
  _tip_proof_assert_not_exists("${_tip_case_root}/install/lib/${PREFIX}${_tip_wrong}${SUFFIX}")
endforeach()
