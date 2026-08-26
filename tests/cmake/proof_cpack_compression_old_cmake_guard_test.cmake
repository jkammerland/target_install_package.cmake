CMAKE_MINIMUM_REQUIRED(VERSION 3.25)

INCLUDE("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

IF(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
ENDIF()
IF(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
ENDIF()
IF(CMAKE_VERSION VERSION_GREATER_EQUAL "4.3")
  _tip_proof_fail("This proof must run with CMake older than 4.3")
ENDIF()

SET(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-compression-old-cmake")
SET(_tip_source_dir "${_tip_case_root}/src")
SET(_tip_build_dir "${_tip_case_root}/build")
FILE(REMOVE_RECURSE "${_tip_case_root}")
FILE(MAKE_DIRECTORY "${_tip_source_dir}")
FILE(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "CMAKE_MINIMUM_REQUIRED(VERSION 3.25)\n"
  "PROJECT(proof_cpack_compression_old_cmake VERSION 1.0.0 LANGUAGES NONE)\n"
  "SET(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "INCLUDE(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "export_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 0)\n")

_tip_proof_append_toolchain_args(_tip_toolchain_args)
_tip_proof_expect_failure(
  NAME
  "compression-level-old-cmake"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_source_dir}"
  -B
  "${_tip_build_dir}"
  ${_tip_toolchain_args}
  EXPECT_CONTAINS
  "require CMake 4.3 or newer")

MESSAGE(STATUS "[proof] CPack compression old-CMake guard passed.")
