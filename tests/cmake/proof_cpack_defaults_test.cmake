cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-defaults")
file(REMOVE_RECURSE "${_tip_case_root}")
_tip_proof_append_toolchain_args(_tip_toolchain_args)

function(_tip_package_default_case name export_call expected_generator suffix)
  set(_tip_source_dir "${_tip_case_root}/${name}-src")
  set(_tip_build_dir "${_tip_case_root}/${name}-build")
  file(MAKE_DIRECTORY "${_tip_source_dir}")
  # Put the call before the install rule to exercise deferred component discovery.
  set(_tip_fixture
      [=[
cmake_minimum_required(VERSION 3.25)
project(DefaultPackage VERSION 1.2.3 LANGUAGES NONE)
include("@TIP_REPO_ROOT@/export_cpack.cmake")
@export_call@
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/payload.txt" "default archive payload\n")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/payload.txt" DESTINATION share/default-package COMPONENT Payload)
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
  if(NOT CPACK_GENERATOR STREQUAL expected_generator)
    _tip_proof_fail("${name}: expected generator ${expected_generator}, got '${CPACK_GENERATOR}'")
  endif()
  if(NOT CPACK_COMPONENTS_ALL STREQUAL "Payload")
    _tip_proof_fail("${name}: manual-only projects must package their installed components")
  endif()

  # Omit -G: the generated configuration must be sufficient on its own.
  _tip_proof_run_step(
    NAME
    "${name}-package"
    COMMAND
    "${CMAKE_CPACK_COMMAND}"
    --config
    "${_tip_build_dir}/CPackConfig.cmake"
    -B
    "${_tip_build_dir}/packages")
  file(GLOB _tip_archives "${_tip_build_dir}/packages/*${suffix}")
  list(LENGTH _tip_archives _tip_archive_count)
  if(NOT _tip_archive_count EQUAL 1)
    _tip_proof_fail("${name}: expected exactly one ${suffix} archive, got '${_tip_archives}'")
  endif()
  list(GET _tip_archives 0 _tip_archive)
  file(MAKE_DIRECTORY "${_tip_build_dir}/extracted")
  file(ARCHIVE_EXTRACT INPUT "${_tip_archive}" DESTINATION "${_tip_build_dir}/extracted")
  file(GLOB_RECURSE _tip_payloads "${_tip_build_dir}/extracted/*payload.txt")
  list(LENGTH _tip_payloads _tip_payload_count)
  if(NOT _tip_payload_count EQUAL 1)
    _tip_proof_fail("${name}: expected one installed payload, got '${_tip_payloads}'")
  endif()
  list(GET _tip_payloads 0 _tip_payload)
  file(READ "${_tip_payload}" _tip_payload_text)
  if(NOT _tip_payload_text STREQUAL "default archive payload\n")
    _tip_proof_fail("${name}: packaged payload differs from the installed file")
  endif()
endfunction()

if(WIN32)
  _tip_package_default_case(zero-arguments "export_cpack()" ZIP .zip)
else()
  _tip_package_default_case(zero-arguments "export_cpack()" TGZ .tar.gz)
endif()
_tip_package_default_case(archive-selection "export_cpack(ARCHIVE_FORMAT ZIP)" ZIP .zip)
_tip_package_default_case(archive-no-defaults "export_cpack(ARCHIVE_FORMAT TGZ NO_DEFAULT_GENERATORS)" TGZ .tar.gz)

message(STATUS "[proof] CPack default configuration and archive selection proof passed.")
