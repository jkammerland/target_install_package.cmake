cmake_minimum_required(VERSION 4.4)

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
if(NOT CMAKE_VERSION VERSION_EQUAL "4.4.2")
  _tip_proof_fail("This proof is pinned to CMake/CPack 4.4.2, got ${CMAKE_VERSION}.")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/archive-reproducibility")
set(_tip_source_dir "${_tip_case_root}/src")
set(_tip_source_date_epoch "1704067200")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/payload/alpha" "${_tip_source_dir}/payload/zulu")
file(WRITE "${_tip_source_dir}/payload/alpha/first.txt" "first payload\n")
file(WRITE "${_tip_source_dir}/payload/zulu/last.txt" "last payload\n")
file(WRITE "${_tip_source_dir}/generated.txt.in" "generated payload\n")
file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_archive_reproducibility VERSION 1.0.0 LANGUAGES NONE)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "configure_file(\"\${CMAKE_CURRENT_SOURCE_DIR}/generated.txt.in\" \"\${CMAKE_CURRENT_BINARY_DIR}/generated.txt\" COPYONLY)\n"
  "install(FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/payload/alpha/first.txt\" \"\${CMAKE_CURRENT_SOURCE_DIR}/payload/zulu/last.txt\" \"\${CMAKE_CURRENT_BINARY_DIR}/generated.txt\" DESTINATION share/proof COMPONENT Runtime)\n"
  "export_cpack(PACKAGE_NAME ReproducibleArchive PACKAGE_VERSION 1.0.0 GENERATORS TGZ COMPONENTS Runtime DEFAULT_COMPONENTS Runtime NO_DEFAULT_GENERATORS ADDITIONAL_CPACK_VARS CPACK_ARCHIVE_THREADS 1 CPACK_PACKAGE_FILE_NAME ReproducibleArchive-1.0.0)\n"
)

execute_process(
  COMMAND "${CMAKE_CPACK_COMMAND}" --version
  RESULT_VARIABLE _tip_cpack_version_result
  OUTPUT_VARIABLE _tip_cpack_version_output
  ERROR_VARIABLE _tip_cpack_version_error)
if(NOT _tip_cpack_version_result EQUAL 0)
  _tip_proof_fail("Unable to identify the pinned CPack toolchain: ${_tip_cpack_version_error}")
endif()
string(FIND "${_tip_cpack_version_output}" "cpack version 4.4.2" _tip_cpack_version_index)
if(_tip_cpack_version_index EQUAL -1)
  _tip_proof_fail("Expected CPack 4.4.2, got: ${_tip_cpack_version_output}")
endif()

_tip_proof_append_toolchain_args(_tip_toolchain_args)

function(_tip_reproducibility_metadata out_var archive_path)
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar tvf "${archive_path}"
    RESULT_VARIABLE _tip_tar_result
    OUTPUT_VARIABLE _tip_tar_output
    ERROR_VARIABLE _tip_tar_error)
  if(NOT _tip_tar_result EQUAL 0)
    set(_tip_tar_output "<unable to inspect ${archive_path}: ${_tip_tar_error}>")
  endif()
  set(${out_var}
      "${_tip_tar_output}"
      PARENT_SCOPE)
endfunction()

function(_tip_create_reproducible_archive name out_var)
  set(_tip_build_dir "${_tip_case_root}/${name}-build")
  set(_tip_package_dir "${_tip_case_root}/${name}-packages")
  file(MAKE_DIRECTORY "${_tip_package_dir}")

  _tip_proof_run_step(
    NAME
    "${name}-configure"
    COMMAND
    "${CMAKE_COMMAND}"
    -E
    env
    "SOURCE_DATE_EPOCH=${_tip_source_date_epoch}"
    "TZ=UTC"
    "LC_ALL=C"
    "LANG=C"
    "${CMAKE_COMMAND}"
    -S
    "${_tip_source_dir}"
    -B
    "${_tip_build_dir}"
    ${_tip_toolchain_args})

  set(_tip_cpack_config "${_tip_build_dir}/CPackConfig.cmake")
  _tip_proof_assert_exists("${_tip_cpack_config}")
  _tip_proof_assert_file_contains("${_tip_cpack_config}" "set(CPACK_ARCHIVE_THREADS \"1\")")
  _tip_proof_run_step(
    NAME
    "${name}-package"
    COMMAND
    "${CMAKE_COMMAND}"
    -E
    env
    "SOURCE_DATE_EPOCH=${_tip_source_date_epoch}"
    "TZ=UTC"
    "LC_ALL=C"
    "LANG=C"
    "${CMAKE_CPACK_COMMAND}"
    -G
    TGZ
    --config
    "${_tip_cpack_config}"
    -B
    "${_tip_package_dir}")

  file(GLOB _tip_archives "${_tip_package_dir}/*.tar.gz")
  list(LENGTH _tip_archives _tip_archive_count)
  if(NOT _tip_archive_count EQUAL 1)
    _tip_proof_fail("Expected one archive from clean build '${name}', got ${_tip_archive_count}: ${_tip_archives}")
  endif()
  list(GET _tip_archives 0 _tip_archive)
  _tip_reproducibility_metadata(_tip_archive_metadata "${_tip_archive}")
  string(FIND "${_tip_archive_metadata}" "share/proof/first.txt" _tip_first_payload_index)
  string(FIND "${_tip_archive_metadata}" "share/proof/last.txt" _tip_last_payload_index)
  string(FIND "${_tip_archive_metadata}" "share/proof/generated.txt" _tip_generated_payload_index)
  if(_tip_first_payload_index EQUAL -1
     OR _tip_last_payload_index EQUAL -1
     OR _tip_generated_payload_index EQUAL -1)
    _tip_proof_fail("Archive '${_tip_archive}' is missing expected source or generated payload:\n${_tip_archive_metadata}")
  endif()

  set(${out_var}
      "${_tip_archive}"
      PARENT_SCOPE)
endfunction()

_tip_create_reproducible_archive(first _tip_first_archive)
_tip_create_reproducible_archive(second _tip_second_archive)

file(SHA256 "${_tip_first_archive}" _tip_first_digest)
file(SHA256 "${_tip_second_archive}" _tip_second_digest)
if(NOT _tip_first_digest STREQUAL _tip_second_digest)
  _tip_reproducibility_metadata(_tip_first_metadata "${_tip_first_archive}")
  _tip_reproducibility_metadata(_tip_second_metadata "${_tip_second_archive}")
  _tip_proof_fail("Reproducibility failure for CMake/CPack 4.4.2 TGZ archives.\n" "SOURCE_DATE_EPOCH=${_tip_source_date_epoch}; TZ=UTC; LC_ALL=C; LANG=C; CPACK_ARCHIVE_THREADS=1.\n"
                  "first SHA256: ${_tip_first_digest}\nsecond SHA256: ${_tip_second_digest}\n" "first archive metadata:\n${_tip_first_metadata}\n" "second archive metadata:\n${_tip_second_metadata}")
endif()

message(STATUS "[proof] Deterministic CPack TGZ archive proof passed: ${_tip_first_digest}")
