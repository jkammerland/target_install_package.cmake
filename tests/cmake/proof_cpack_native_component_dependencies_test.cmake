cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

function(_tip_assert_cpack_var_equals config_file var_name expected)
  _tip_proof_assert_exists("${config_file}")
  file(READ "${config_file}" _tip_config_content)
  string(REGEX MATCH "set\\(${var_name} \"([^\"]*)\"\\)" _tip_match "${_tip_config_content}")
  if(NOT _tip_match)
    _tip_proof_fail("Expected ${config_file} to define ${var_name}")
  endif()
  if(NOT "${CMAKE_MATCH_1}" STREQUAL "${expected}")
    _tip_proof_fail("Expected ${var_name} to be '${expected}', got '${CMAKE_MATCH_1}'")
  endif()
endfunction()

function(_tip_assert_cpack_var_contains_list_item config_file var_name expected)
  _tip_proof_assert_exists("${config_file}")
  file(READ "${config_file}" _tip_config_content)
  string(REGEX MATCH "set\\(${var_name} \"([^\"]*)\"\\)" _tip_match "${_tip_config_content}")
  if(NOT _tip_match)
    _tip_proof_fail("Expected ${config_file} to define ${var_name}")
  endif()
  set(_tip_value "${CMAKE_MATCH_1}")
  if(NOT "${expected}" IN_LIST _tip_value)
    _tip_proof_fail("Expected ${var_name} to include list item '${expected}', got '${_tip_value}'")
  endif()
endfunction()

function(_tip_assert_cpack_var_not_contains config_file var_name unexpected)
  _tip_proof_assert_exists("${config_file}")
  file(READ "${config_file}" _tip_config_content)
  string(REGEX MATCH "set\\(${var_name} \"([^\"]*)\"\\)" _tip_match "${_tip_config_content}")
  if(NOT _tip_match)
    return()
  endif()
  string(FIND "${CMAKE_MATCH_1}" "${unexpected}" _tip_unexpected_index)
  if(NOT _tip_unexpected_index EQUAL -1)
    _tip_proof_fail("Did not expect ${var_name} to contain '${unexpected}', got '${CMAKE_MATCH_1}'")
  endif()
endfunction()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-native-component-dependencies")
set(_tip_generated_source_dir "${_tip_case_root}/generated-src")
set(_tip_generated_build_dir "${_tip_case_root}/generated-build")
set(_tip_override_source_dir "${_tip_case_root}/override-src")
set(_tip_override_build_dir "${_tip_case_root}/override-build")
set(_tip_group_source_dir "${_tip_case_root}/group-src")
set(_tip_group_build_dir "${_tip_case_root}/group-build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_generated_source_dir}/src" "${_tip_override_source_dir}/src" "${_tip_group_source_dir}")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

string(
  CONCAT _tip_shared_fixture_prefix
         "cmake_minimum_required(VERSION 3.25)\n"
         "project(proof_native_component_dependencies VERSION 2.0.0 LANGUAGES CXX)\n"
         "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
         "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
         "add_library(native_core SHARED src/core.cpp)\n"
         "set_target_properties(native_core PROPERTIES VERSION \${PROJECT_VERSION} SOVERSION 2)\n"
         "target_compile_features(native_core PUBLIC cxx_std_17)\n"
         "add_executable(native_tool src/tool.cpp)\n"
         "target_link_libraries(native_tool PRIVATE native_core)\n"
         "if(WIN32)\n"
         "  set_target_properties(native_core PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)\n"
         "endif()\n"
         "target_install_package(native_core EXPORT_NAME NativeProofPkg NAMESPACE Native::)\n"
         "target_install_package(native_tool EXPORT_NAME NativeProofPkg NAMESPACE Native:: COMPONENT Tools)\n")

file(
  WRITE "${_tip_generated_source_dir}/CMakeLists.txt"
  "${_tip_shared_fixture_prefix}"
  "export_cpack(PACKAGE_NAME NativeProof PACKAGE_VERSION 2.0.0-beta PACKAGE_CONTACT test@example.com PACKAGE_LICENSE MIT GENERATORS DEB RPM NO_DEFAULT_GENERATORS ADDITIONAL_CPACK_VARS CPACK_RPM_PACKAGE_RELEASE 4 CPACK_RPM_PACKAGE_EPOCH 2)\n"
)

file(WRITE "${_tip_generated_source_dir}/src/core.cpp" "int native_core_value() { return 7; }\n")
file(WRITE "${_tip_generated_source_dir}/src/tool.cpp" "int native_core_value(); int main() { return native_core_value() == 7 ? 0 : 1; }\n")

file(
  WRITE "${_tip_override_source_dir}/CMakeLists.txt"
  "${_tip_shared_fixture_prefix}"
  "export_cpack(PACKAGE_NAME NativeProof PACKAGE_VERSION 2.0.0-beta PACKAGE_CONTACT test@example.com PACKAGE_LICENSE MIT GENERATORS DEB RPM NO_DEFAULT_GENERATORS ADDITIONAL_CPACK_VARS CPACK_DEBIAN_ENABLE_COMPONENT_DEPENDS OFF CPACK_RPM_DEVELOPMENT_PACKAGE_REQUIRES \"manual-runtime >= 9\")\n"
)

file(WRITE "${_tip_override_source_dir}/src/core.cpp" "int native_core_value() { return 7; }\n")
file(WRITE "${_tip_override_source_dir}/src/tool.cpp" "int native_core_value(); int main() { return native_core_value() == 7 ? 0 : 1; }\n")

file(
  WRITE "${_tip_group_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_group_native_dependencies VERSION 1.0.0 LANGUAGES NONE)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "file(WRITE \"\${CMAKE_CURRENT_BINARY_DIR}/foo.txt\" \"foo\\n\")\n"
  "file(WRITE \"\${CMAKE_CURRENT_BINARY_DIR}/dev.txt\" \"dev\\n\")\n"
  "file(WRITE \"\${CMAKE_CURRENT_BINARY_DIR}/runtime.txt\" \"runtime\\n\")\n"
  "install(FILES \"\${CMAKE_CURRENT_BINARY_DIR}/foo.txt\" DESTINATION share COMPONENT Foo)\n"
  "install(FILES \"\${CMAKE_CURRENT_BINARY_DIR}/dev.txt\" DESTINATION share COMPONENT Foo_Development)\n"
  "install(FILES \"\${CMAKE_CURRENT_BINARY_DIR}/runtime.txt\" DESTINATION share COMPONENT Runtime)\n"
  "export_cpack(PACKAGE_NAME GroupNative PACKAGE_VERSION \${PROJECT_VERSION} PACKAGE_CONTACT test@example.com PACKAGE_LICENSE MIT GENERATORS DEB RPM TGZ COMPONENTS Foo Foo_Development Runtime COMPONENT_GROUPS NO_DEFAULT_GENERATORS ADDITIONAL_CPACK_VARS CPACK_RPM_PACKAGE_RELEASE 3)\n"
)

_tip_proof_run_step(
  NAME
  "generated-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_generated_source_dir}"
  -B
  "${_tip_generated_build_dir}"
  "-DCMAKE_BUILD_TYPE=Release"
  ${_tip_toolchain_args})

set(_tip_generated_cpack_config "${_tip_generated_build_dir}/CPackConfig.cmake")
_tip_assert_cpack_var_equals("${_tip_generated_cpack_config}" "CPACK_DEBIAN_ENABLE_COMPONENT_DEPENDS" "ON")
_tip_assert_cpack_var_contains_list_item("${_tip_generated_cpack_config}" "CPACK_COMPONENT_DEVELOPMENT_DEPENDS" "Runtime")
_tip_assert_cpack_var_contains_list_item("${_tip_generated_cpack_config}" "CPACK_COMPONENT_DEVELOPMENT_DEPENDS" "Tools")
_tip_assert_cpack_var_equals("${_tip_generated_cpack_config}" "CPACK_RPM_DEVELOPMENT_PACKAGE_REQUIRES" "nativeproof-Runtime = 2:2.0.0_beta-4, nativeproof-Tools = 2:2.0.0_beta-4")

_tip_proof_run_step(
  NAME
  "override-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_override_source_dir}"
  -B
  "${_tip_override_build_dir}"
  "-DCMAKE_BUILD_TYPE=Release"
  ${_tip_toolchain_args})

set(_tip_override_cpack_config "${_tip_override_build_dir}/CPackConfig.cmake")
_tip_assert_cpack_var_equals("${_tip_override_cpack_config}" "CPACK_DEBIAN_ENABLE_COMPONENT_DEPENDS" "OFF")
_tip_assert_cpack_var_equals("${_tip_override_cpack_config}" "CPACK_RPM_DEVELOPMENT_PACKAGE_REQUIRES" "manual-runtime >= 9")

_tip_proof_run_step(
  NAME
  "group-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_group_source_dir}"
  -B
  "${_tip_group_build_dir}"
  ${_tip_toolchain_args})

set(_tip_group_cpack_config "${_tip_group_build_dir}/CPackConfig.cmake")
_tip_assert_cpack_var_equals("${_tip_group_cpack_config}" "CPACK_COMPONENTS_GROUPING" "ONE_PER_GROUP")
_tip_assert_cpack_var_equals("${_tip_group_cpack_config}" "CPACK_COMPONENT_FOO_DEPENDS" "Runtime")
_tip_assert_cpack_var_equals("${_tip_group_cpack_config}" "CPACK_RPM_FOO_PACKAGE_REQUIRES" "groupnative-Runtime = 1.0.0-3")
_tip_assert_cpack_var_not_contains("${_tip_group_cpack_config}" "CPACK_RPM_FOO_PACKAGE_REQUIRES" "groupnative-FOO")
_tip_assert_cpack_var_not_contains("${_tip_group_cpack_config}" "CPACK_RPM_FOO_DEVELOPMENT_PACKAGE_REQUIRES" "groupnative-FOO")

message(STATUS "[proof] CPack native component dependency proof passed.")
