cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-scope-isolation")
file(REMOVE_RECURSE "${_tip_case_root}")
_tip_proof_append_toolchain_args(_tip_toolchain_args)
set(ENV{GPG_SIGNING_KEY} "")

function(
  _tip_scope_case
  name
  scope_arguments
  export_call
  expected_generator
  expected_vendor
  expected_contact)
  set(_tip_source_dir "${_tip_case_root}/${name}-source")
  set(_tip_build_dir "${_tip_case_root}/${name}-build")
  file(MAKE_DIRECTORY "${_tip_source_dir}")
  set(_tip_fixture
      [=[
cmake_minimum_required(VERSION 3.25)
project(ScopePackage VERSION 1.2.3 DESCRIPTION "Project description" HOMEPAGE_URL "https://project.invalid" LANGUAGES NONE)
include("@TIP_REPO_ROOT@/export_cpack.cmake")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/payload.txt" "scope payload\n")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/payload.txt" DESTINATION share/scope COMPONENT Payload)

# These belong to unrelated callers and must not configure export_cpack().
set(ARG_PACKAGE_NAME OuterPackage @scope_arguments@)
set(ARG_PACKAGE_VERSION 7.8.9 @scope_arguments@)
set(ARG_PACKAGE_DESCRIPTION "Outer description" @scope_arguments@)
set(ARG_PACKAGE_HOMEPAGE_URL "https://outer.invalid" @scope_arguments@)
set(ARG_PACKAGE_VENDOR OuterVendor @scope_arguments@)
set(ARG_PACKAGE_CONTACT OuterContact @scope_arguments@)
set(ARG_GENERATORS ZIP @scope_arguments@)
set(ARG_ARCHIVE_FORMAT RPM @scope_arguments@)
set(ARG_COMPONENTS OuterComponent @scope_arguments@)
set(ARG_DEFAULT_COMPONENTS OuterDefault @scope_arguments@)
set(ARG_NO_DEFAULT_GENERATORS TRUE @scope_arguments@)
set(ARG_ENABLE_COMPONENT_INSTALL TRUE @scope_arguments@)
set(ARG_SIGNING_METHOD embedded @scope_arguments@)
set(ARG_GPG_SIGNING_KEY missing-outer-key @scope_arguments@)
@export_call@
]=])
  string(CONFIGURE "${_tip_fixture}" _tip_fixture @ONLY)
  file(WRITE "${_tip_source_dir}/CMakeLists.txt" "${_tip_fixture}")
  _tip_proof_run_step(
    NAME
    "${name}-configure"
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${_tip_source_dir}"
    -B
    "${_tip_build_dir}"
    ${_tip_toolchain_args})
  include("${_tip_build_dir}/CPackConfig.cmake")
  if(NOT CPACK_PACKAGE_NAME STREQUAL "ScopePackage"
     OR NOT CPACK_PACKAGE_VERSION STREQUAL "1.2.3"
     OR NOT CPACK_PACKAGE_DESCRIPTION_SUMMARY STREQUAL "Project description"
     OR NOT CPACK_PACKAGE_HOMEPAGE_URL STREQUAL "https://project.invalid")
    _tip_proof_fail("${name}: unrelated ARG_* metadata replaced project defaults")
  endif()
  if(NOT CPACK_PACKAGE_VENDOR STREQUAL expected_vendor OR NOT CPACK_PACKAGE_CONTACT STREQUAL expected_contact)
    _tip_proof_fail("${name}: absent and explicitly empty metadata were not distinguished")
  endif()
  if(NOT CPACK_GENERATOR STREQUAL expected_generator
     OR NOT CPACK_COMPONENTS_ALL STREQUAL "Payload"
     OR CPACK_ARCHIVE_COMPONENT_INSTALL)
    _tip_proof_fail("${name}: unrelated ARG_* options or lists affected package configuration")
  endif()
endfunction()

if(WIN32)
  set(_tip_default_generator ZIP)
else()
  set(_tip_default_generator TGZ)
endif()
foreach(_tip_scope normal cache)
  set(_tip_scope_arguments "")
  if(_tip_scope STREQUAL "cache")
    set(_tip_scope_arguments "CACHE STRING \"Unrelated input\"")
  endif()
  _tip_scope_case("${_tip_scope}-defaults" "${_tip_scope_arguments}" "export_cpack()" "${_tip_default_generator}" project.invalid maintainer@project.invalid)
  _tip_scope_case("${_tip_scope}-archive" "${_tip_scope_arguments}" "export_cpack(ARCHIVE_FORMAT TGZ)" TGZ project.invalid maintainer@project.invalid)
  _tip_scope_case("${_tip_scope}-empty" "${_tip_scope_arguments}" "export_cpack(PACKAGE_VENDOR \"\" PACKAGE_CONTACT \"\")" "${_tip_default_generator}" "" "")
endforeach()
message(STATUS "[proof] CPack parsed argument scope isolation proof passed.")
