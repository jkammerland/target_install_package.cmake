cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()
if(NOT CMAKE_VERSION VERSION_LESS "4.3")
  _tip_proof_fail("proof_archive_ownership_old_cmake_guard requires CMake older than 4.3")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/archive-ownership-old-cmake-guard")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_case_root}")
_tip_proof_append_toolchain_args(_tip_toolchain_args)

set(_tip_omitted_source_dir "${_tip_case_root}/omitted-src")
set(_tip_omitted_build_dir "${_tip_case_root}/omitted-build")
file(MAKE_DIRECTORY "${_tip_omitted_source_dir}")
file(WRITE "${_tip_omitted_source_dir}/payload.txt" "old CMake archive ownership proof\n")
file(
  WRITE "${_tip_omitted_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n" "project(proof_archive_ownership_omitted_old_cmake VERSION 1.0.0 LANGUAGES NONE)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n" "install(FILES payload.txt DESTINATION share/proof COMPONENT Runtime)\n"
  "export_cpack(PACKAGE_NAME ProofOwnershipOmitted GENERATORS TGZ COMPONENTS Runtime NO_DEFAULT_GENERATORS)\n")
_tip_proof_run_step(
  NAME
  "omitted-on-old-cmake"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_omitted_source_dir}"
  -B
  "${_tip_omitted_build_dir}"
  ${_tip_toolchain_args})
_tip_proof_assert_file_not_contains("${_tip_omitted_build_dir}/CPackConfig.cmake" "CPACK_ARCHIVE_UID")
_tip_proof_assert_file_not_contains("${_tip_omitted_build_dir}/CPackConfig.cmake" "CPACK_ARCHIVE_GID")

function(_tip_expect_old_cmake_ownership_guard name ownership_args)
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
    "CMake 4.3 or newer")
endfunction()

_tip_expect_old_cmake_ownership_guard("archive-uid-old-cmake" "ARCHIVE_UID 0")
_tip_expect_old_cmake_ownership_guard("archive-gid-old-cmake" "ARCHIVE_GID 0")

message(STATUS "[proof] Archive ownership old-CMake guard proof passed.")
