cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()
if(NOT CMAKE_CPACK_COMMAND)
  _tip_proof_fail("CMAKE_CPACK_COMMAND is required")
endif()
if(CMAKE_VERSION VERSION_LESS "4.3")
  _tip_proof_fail("proof_archive_ownership requires CMake 4.3 or newer")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/archive-ownership")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_case_root}")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

function(_tip_configure_ownership_case name ownership_args out_build_dir)
  set(_tip_source_dir "${_tip_case_root}/${name}-src")
  set(_tip_build_dir "${_tip_case_root}/${name}-build")
  file(MAKE_DIRECTORY "${_tip_source_dir}/nested")
  file(WRITE "${_tip_source_dir}/payload.txt" "archive ownership proof\n")
  file(WRITE "${_tip_source_dir}/nested/inner.txt" "nested archive ownership proof\n")

  if(UNIX)
    file(CREATE_LINK "nested/inner.txt" "${_tip_source_dir}/payload-link.txt" SYMBOLIC RESULT _tip_link_result)
    if(NOT _tip_link_result STREQUAL "0")
      _tip_proof_fail("Unable to create archive ownership symlink: ${_tip_link_result}")
    endif()
  endif()

  file(
    WRITE "${_tip_source_dir}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 3.25)\n"
    "project(proof_archive_ownership_${name} VERSION 1.0.0 LANGUAGES NONE)\n"
    "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
    "install(FILES payload.txt DESTINATION share/proof COMPONENT Runtime)\n"
    "install(DIRECTORY nested DESTINATION share/proof COMPONENT Runtime)\n"
    "if(UNIX)\n"
    "  install(FILES payload-link.txt DESTINATION share/proof COMPONENT Runtime)\n"
    "endif()\n"
    "export_cpack(PACKAGE_NAME ProofOwnership-${name} PACKAGE_VERSION 1.0.0 GENERATORS TGZ COMPONENTS Runtime DEFAULT_COMPONENTS Runtime NO_DEFAULT_GENERATORS ${ownership_args})\n")

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

  set(${out_build_dir}
      "${_tip_build_dir}"
      PARENT_SCOPE)
endfunction()

_tip_configure_ownership_case("omitted" "" _tip_omitted_build_dir)
_tip_proof_assert_file_contains("${_tip_omitted_build_dir}/CPackConfig.cmake" "set(CPACK_ARCHIVE_UID \"-1\")")
_tip_proof_assert_file_contains("${_tip_omitted_build_dir}/CPackConfig.cmake" "set(CPACK_ARCHIVE_GID \"-1\")")

_tip_configure_ownership_case("uid-only" "ARCHIVE_UID 0" _tip_uid_only_build_dir)
_tip_proof_assert_file_contains("${_tip_uid_only_build_dir}/CPackConfig.cmake" "set(CPACK_ARCHIVE_UID \"0\")")
_tip_proof_assert_file_not_contains("${_tip_uid_only_build_dir}/CPackConfig.cmake" "set(CPACK_ARCHIVE_GID")

_tip_configure_ownership_case("gid-only" "ARCHIVE_GID 3456" _tip_gid_only_build_dir)
_tip_proof_assert_file_not_contains("${_tip_gid_only_build_dir}/CPackConfig.cmake" "set(CPACK_ARCHIVE_UID")
_tip_proof_assert_file_contains("${_tip_gid_only_build_dir}/CPackConfig.cmake" "set(CPACK_ARCHIVE_GID \"3456\")")

_tip_configure_ownership_case("both" "ARCHIVE_UID 17321 ARCHIVE_GID 17322" _tip_both_build_dir)
set(_tip_both_cpack_config "${_tip_both_build_dir}/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_both_cpack_config}" "set(CPACK_ARCHIVE_UID \"17321\")")
_tip_proof_assert_file_contains("${_tip_both_cpack_config}" "set(CPACK_ARCHIVE_GID \"17322\")")

find_program(_tip_tar_command NAMES tar bsdtar)
function(_tip_package_and_assert_ownership name build_dir expected_uid expected_gid out_archive)
  set(_tip_package_dir "${_tip_case_root}/${name}-packages")
  file(MAKE_DIRECTORY "${_tip_package_dir}")
  _tip_proof_run_step(
    NAME
    "${name}-package"
    COMMAND
    "${CMAKE_CPACK_COMMAND}"
    -G
    TGZ
    --config
    "${build_dir}/CPackConfig.cmake"
    -B
    "${_tip_package_dir}")
  file(GLOB _tip_archives "${_tip_package_dir}/*.tar.gz")
  list(LENGTH _tip_archives _tip_archive_count)
  if(NOT _tip_archive_count EQUAL 1)
    _tip_proof_fail("Expected one ownership proof archive for ${name}, got ${_tip_archive_count}: ${_tip_archives}")
  endif()
  list(GET _tip_archives 0 _tip_archive)

  if(_tip_tar_command)
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E env "LC_ALL=C" "${_tip_tar_command}" --numeric-owner -tvf "${_tip_archive}"
      RESULT_VARIABLE _tip_tar_result
      OUTPUT_VARIABLE _tip_tar_output
      ERROR_VARIABLE _tip_tar_error)
    if(NOT _tip_tar_result EQUAL 0)
      _tip_proof_fail("Unable to inspect numeric archive ownership with ${_tip_tar_command}: ${_tip_tar_error}")
    endif()

    string(REGEX MATCHALL "[^\n]+" _tip_tar_lines "${_tip_tar_output}")
    if(NOT _tip_tar_lines)
      _tip_proof_fail("Numeric archive ownership inspection produced no entries for ${_tip_archive}")
    endif()
    foreach(_tip_tar_line IN LISTS _tip_tar_lines)
      if(NOT _tip_tar_line MATCHES "[ \t]${expected_uid}/${expected_gid}[ \t]" AND NOT _tip_tar_line MATCHES "[ \t]${expected_uid}[ \t]+${expected_gid}[ \t]")
        _tip_proof_fail("Archive entry does not store UID/GID ${expected_uid}/${expected_gid}: ${_tip_tar_line}")
      endif()
    endforeach()
    string(FIND "${_tip_tar_output}" "share/proof/nested/inner.txt" _tip_nested_index)
    if(_tip_nested_index EQUAL -1)
      _tip_proof_fail("Ownership proof archive is missing its nested payload:\n${_tip_tar_output}")
    endif()
    if(UNIX)
      string(FIND "${_tip_tar_output}" "payload-link.txt -> nested/inner.txt" _tip_symlink_index)
      if(_tip_symlink_index EQUAL -1)
        _tip_proof_fail("Ownership proof archive is missing its symlink payload:\n${_tip_tar_output}")
      endif()
    endif()
  else()
    message(STATUS "[proof] tar/bsdtar not found; generated ${name} ownership archive was not inspected on this host")
  endif()

  set(${out_archive}
      "${_tip_archive}"
      PARENT_SCOPE)
endfunction()

_tip_package_and_assert_ownership("uid-only" "${_tip_uid_only_build_dir}" 0 0 _tip_uid_only_archive)
_tip_package_and_assert_ownership("gid-only" "${_tip_gid_only_build_dir}" 0 3456 _tip_gid_only_archive)
_tip_package_and_assert_ownership("both" "${_tip_both_build_dir}" 17321 17322 _tip_both_archive)

function(_tip_expect_invalid_ownership name ownership_args expected)
  set(_tip_source_dir "${_tip_case_root}/${name}-src")
  set(_tip_build_dir "${_tip_case_root}/${name}-build")
  file(MAKE_DIRECTORY "${_tip_source_dir}")
  file(WRITE "${_tip_source_dir}/CMakeLists.txt" "cmake_minimum_required(VERSION 3.25)\n" "project(proof_${name} VERSION 1.0.0 LANGUAGES NONE)\n"
                                                 "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n" "export_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS ${ownership_args})\n")
  _tip_proof_expect_failure(
    NAME
    "${name}"
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${_tip_source_dir}"
    -B
    "${_tip_build_dir}"
    ${_tip_toolchain_args}
    EXPECT_CONTAINS
    "${expected}")
endfunction()

_tip_expect_invalid_ownership("archive-uid-nonnumeric" "ARCHIVE_UID owner" "got: 'owner'")
_tip_expect_invalid_ownership("archive-gid-negative" "ARCHIVE_GID -1" "got: '-1'")
_tip_expect_invalid_ownership("archive-uid-missing" "ARCHIVE_UID ARCHIVE_GID 0" "ARCHIVE_UID requires")

message(STATUS "[proof] Deterministic archive ownership proof passed: ${_tip_both_archive}")
