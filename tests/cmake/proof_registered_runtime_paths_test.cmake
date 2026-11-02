cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/registered-runtime-paths")
file(REMOVE_RECURSE "${_tip_case_root}")
_tip_proof_append_toolchain_args(_tip_toolchain_args)

# Run grouped and separate exports, with a different layout on each level of the shared-library chain.
foreach(_tip_case IN ITEMS grouped_fhs separate_fhs grouped_mixed_debug separate_mixed_release)
  set(_tip_source "${_tip_case_root}/${_tip_case}/source")
  set(_tip_build "${_tip_case_root}/${_tip_case}/build")
  set(_tip_install "${_tip_case_root}/${_tip_case}/install")
  set(_tip_relocated "${_tip_case_root}/${_tip_case}/relocated")
  set(_tip_configuration Release)
  set(_tip_leaf_layout fhs)
  set(_tip_bridge_layout fhs)
  if(_tip_case MATCHES "mixed")
    set(_tip_leaf_layout split_all)
    set(_tip_bridge_layout split_debug)
  endif()
  if(_tip_case MATCHES "debug$")
    set(_tip_configuration Debug)
  endif()
  set(_tip_app_export RuntimeGroup)
  set(_tip_bridge_export RuntimeGroup)
  set(_tip_leaf_export RuntimeGroup)
  if(_tip_case MATCHES "^separate")
    set(_tip_app_export RuntimeApp)
    set(_tip_bridge_export RuntimeBridge)
    set(_tip_leaf_export RuntimeLeaf)
  endif()

  set(_tip_project
      [=[
cmake_minimum_required(VERSION 3.25)
project(RuntimePaths VERSION 1.0.0 LANGUAGES CXX)
include("@TIP_REPO_ROOT@/target_install_package.cmake")
# Register consumers first so separate exports finalize before their dependencies.
add_subdirectory(app)
add_subdirectory(bridge)
add_subdirectory(leaf)
]=])
  string(CONFIGURE "${_tip_project}" _tip_project @ONLY)
  file(WRITE "${_tip_source}/CMakeLists.txt" "${_tip_project}")

  set(_tip_app
      [=[
set(CMAKE_INSTALL_BINDIR app/bin)
set(CMAKE_INSTALL_LIBDIR app/lib)
add_library(runtime_interface INTERFACE)
target_link_libraries(runtime_interface INTERFACE
  "$<$<CONFIG:Debug>:$<LINK_ONLY:Bridge::library>>"
  "$<$<NOT:$<CONFIG:Debug>>:$<LINK_ONLY:Bridge::library>>")
add_library(runtime_facade STATIC facade.cpp)
target_link_libraries(runtime_facade PUBLIC runtime_interface)
add_executable(runtime_app main.cpp)
target_link_libraries(runtime_app PRIVATE runtime_facade)
target_install_package(runtime_app EXPORT_NAME @_tip_app_export@ NAMESPACE Runtime:: CMAKE_CONFIG_DESTINATION common/cmake ADDITIONAL_TARGETS runtime_facade runtime_interface)

# Explicit target/global RPATHs and DISABLE_RPATH continue to take precedence.
add_executable(runtime_explicit main.cpp)
target_link_libraries(runtime_explicit PRIVATE runtime_facade)
set_property(TARGET runtime_explicit PROPERTY INSTALL_RPATH /explicit/target/path)
target_install_package(runtime_explicit EXPORT_NAME @_tip_app_export@ NAMESPACE Runtime:: CMAKE_CONFIG_DESTINATION common/cmake)
set(CMAKE_INSTALL_RPATH /explicit/global/path)
add_executable(runtime_global main.cpp)
target_link_libraries(runtime_global PRIVATE runtime_facade)
target_install_package(runtime_global EXPORT_NAME @_tip_app_export@ NAMESPACE Runtime:: CMAKE_CONFIG_DESTINATION common/cmake)
unset(CMAKE_INSTALL_RPATH)
add_executable(runtime_disabled main.cpp)
target_link_libraries(runtime_disabled PRIVATE runtime_facade)
target_install_package(runtime_disabled EXPORT_NAME @_tip_app_export@ NAMESPACE Runtime:: CMAKE_CONFIG_DESTINATION common/cmake DISABLE_RPATH)
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/rpaths-$<CONFIG>.txt" CONTENT "explicit=$<TARGET_PROPERTY:runtime_explicit,INSTALL_RPATH>\nglobal=$<TARGET_PROPERTY:runtime_global,INSTALL_RPATH>\ndisabled=$<TARGET_PROPERTY:runtime_disabled,INSTALL_RPATH>\n")
]=])
  string(CONFIGURE "${_tip_app}" _tip_app @ONLY)
  file(WRITE "${_tip_source}/app/CMakeLists.txt" "${_tip_app}")
  file(WRITE "${_tip_source}/app/main.cpp" "int facade(); int main() { return facade() == 42 ? 0 : 1; }\n")
  file(WRITE "${_tip_source}/app/facade.cpp" "int bridge(); int facade() { return bridge() + 1; }\n")

  set(_tip_bridge
      [=[
set(CMAKE_INSTALL_LIBDIR bridge/lib)
add_library(runtime_bridge SHARED bridge.cpp)
add_library(Bridge::library ALIAS runtime_bridge)
target_link_libraries(runtime_bridge PRIVATE Leaf::library)
target_install_package(runtime_bridge EXPORT_NAME @_tip_bridge_export@ NAMESPACE Runtime:: CMAKE_CONFIG_DESTINATION common/cmake LAYOUT @_tip_bridge_layout@)
]=])
  string(CONFIGURE "${_tip_bridge}" _tip_bridge @ONLY)
  file(WRITE "${_tip_source}/bridge/CMakeLists.txt" "${_tip_bridge}")
  file(WRITE "${_tip_source}/bridge/bridge.cpp" "int leaf(); int bridge() { return leaf() + 1; }\n")

  set(_tip_leaf
      [=[
set(CMAKE_INSTALL_LIBDIR leaf/lib)
add_library(runtime_leaf SHARED leaf.cpp)
add_library(Leaf::library ALIAS runtime_leaf)
target_install_package(runtime_leaf EXPORT_NAME @_tip_leaf_export@ NAMESPACE Runtime:: CMAKE_CONFIG_DESTINATION common/cmake LAYOUT @_tip_leaf_layout@)
]=])
  string(CONFIGURE "${_tip_leaf}" _tip_leaf @ONLY)
  file(WRITE "${_tip_source}/leaf/CMakeLists.txt" "${_tip_leaf}")
  file(WRITE "${_tip_source}/leaf/leaf.cpp" "int leaf() { return 40; }\n")

  _tip_proof_run_step(
    NAME
    "${_tip_case}-configure"
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${_tip_source}"
    -B
    "${_tip_build}"
    "-DCMAKE_BUILD_TYPE=${_tip_configuration}"
    ${_tip_toolchain_args})
  _tip_proof_run_step(
    NAME
    "${_tip_case}-build"
    COMMAND
    "${CMAKE_COMMAND}"
    --build
    "${_tip_build}"
    --config
    "${_tip_configuration}")
  _tip_proof_run_step(
    NAME
    "${_tip_case}-install"
    COMMAND
    "${CMAKE_COMMAND}"
    --install
    "${_tip_build}"
    --config
    "${_tip_configuration}"
    --prefix
    "${_tip_install}")
  file(READ "${_tip_build}/rpaths-${_tip_configuration}.txt" _tip_explicit_rpaths)
  if(NOT _tip_explicit_rpaths STREQUAL "explicit=/explicit/target/path\nglobal=/explicit/global/path\ndisabled=\n")
    _tip_proof_fail("Explicit/disabled RPATH settings changed: ${_tip_explicit_rpaths}")
  endif()

  # A real relocated process checks executable and shared-library dependency lookup without environment help.
  file(RENAME "${_tip_install}" "${_tip_relocated}")
  _tip_proof_run_step(
    NAME
    "${_tip_case}-relocated-run"
    COMMAND
    "${CMAKE_COMMAND}"
    -E
    env
    --unset=LD_LIBRARY_PATH
    --unset=DYLD_LIBRARY_PATH
    --unset=DYLD_FALLBACK_LIBRARY_PATH
    "${_tip_relocated}/app/bin/runtime_app")
endforeach()

# Expressions outside the bounded target/configuration forms require an explicit RPATH.
# Verify that this limitation is diagnosed rather than silently promising runtime discovery.
file(
  APPEND "${_tip_source}/app/CMakeLists.txt"
  "add_executable(runtime_unresolved main.cpp)\ntarget_link_libraries(runtime_unresolved PRIVATE \"$<IF:$<CONFIG:Debug>,runtime_facade,runtime_facade>\")\ntarget_install_package(runtime_unresolved EXPORT_NAME ${_tip_app_export} NAMESPACE Runtime:: CMAKE_CONFIG_DESTINATION common/cmake)\n"
)
execute_process(
  COMMAND "${CMAKE_COMMAND}" -S "${_tip_source}" -B "${_tip_case_root}/unresolved-build" -DCMAKE_BUILD_TYPE=Release ${_tip_toolchain_args}
  RESULT_VARIABLE _tip_unresolved_result
  OUTPUT_VARIABLE _tip_unresolved_output
  ERROR_VARIABLE _tip_unresolved_error)
if(NOT _tip_unresolved_result EQUAL 0)
  _tip_proof_fail("Unresolved-expression configure failed: ${_tip_unresolved_output} ${_tip_unresolved_error}")
endif()
string(FIND "${_tip_unresolved_output}\n${_tip_unresolved_error}" "Automatic RPATH cannot resolve link expression" _tip_warning_index)
if(_tip_warning_index EQUAL -1)
  _tip_proof_fail("Expected unresolved link expression warning: ${_tip_unresolved_output} ${_tip_unresolved_error}")
endif()
