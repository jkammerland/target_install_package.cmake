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

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-checksums")
set(_tip_source_dir "${_tip_case_root}/src")
set(_tip_build_dir "${_tip_case_root}/build")
set(_tip_package_dir "${_tip_case_root}/packages")
set(_tip_algorithms
    MD5
    SHA1
    SHA224
    SHA256
    SHA384
    SHA512
    SHA3_224
    SHA3_256
    SHA3_384
    SHA3_512)

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}" "${_tip_package_dir}")
file(WRITE "${_tip_source_dir}/payload.txt" "checksum proof\n")
file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n" "project(proof_cpack_checksums VERSION 1.0.0 LANGUAGES NONE)\n" "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n" "install(FILES payload.txt DESTINATION share/proof)\n"
  "export_cpack(PACKAGE_NAME ProofChecksums PACKAGE_VERSION 1.0.0 GENERATORS TGZ NO_DEFAULT_GENERATORS CHECKSUMS md5 sha1 sha224 sha256 sha384 sha512 sha3_224 sha3_256 sha3_384 sha3_512)\n")

_tip_proof_append_toolchain_args(_tip_toolchain_args)
_tip_proof_run_step(
  NAME
  "configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_source_dir}"
  -B
  "${_tip_build_dir}"
  ${_tip_toolchain_args})

set(_tip_cpack_config "${_tip_build_dir}/CPackConfig.cmake")
_tip_proof_assert_exists("${_tip_cpack_config}")
if(CMAKE_VERSION VERSION_GREATER_EQUAL "4.2")
  _tip_proof_assert_file_contains("${_tip_cpack_config}" "set(CPACK_PACKAGE_CHECKSUM \"${_tip_algorithms}\")")
  _tip_proof_assert_not_exists("${_tip_build_dir}/sign_packages.cmake")
else()
  _tip_proof_assert_file_not_contains("${_tip_cpack_config}" "CPACK_PACKAGE_CHECKSUM")
  _tip_proof_assert_file_contains("${_tip_build_dir}/sign_packages.cmake" "set(CHECKSUMS \"${_tip_algorithms}\")")
endif()

_tip_proof_run_step(
  NAME
  "package"
  COMMAND
  "${CMAKE_CPACK_COMMAND}"
  -G
  TGZ
  --config
  "${_tip_cpack_config}"
  -B
  "${_tip_package_dir}")
file(GLOB _tip_packages "${_tip_package_dir}/*.tar.gz")
list(LENGTH _tip_packages _tip_package_count)
if(_tip_package_count EQUAL 0)
  _tip_proof_fail("Expected at least one TGZ package")
endif()

foreach(_tip_package IN LISTS _tip_packages)
  foreach(_tip_algorithm IN LISTS _tip_algorithms)
    string(TOLOWER "${_tip_algorithm}" _tip_extension)
    set(_tip_checksum_file "${_tip_package}.${_tip_extension}")
    _tip_proof_assert_exists("${_tip_checksum_file}")
    file(${_tip_algorithm} "${_tip_package}" _tip_expected_hash)
    _tip_proof_assert_file_contains("${_tip_checksum_file}" "${_tip_expected_hash}")
  endforeach()
endforeach()

function(_tip_write_invalid_fixture name invocation expected)
  set(_tip_invalid_source_dir "${_tip_case_root}/${name}-src")
  set(_tip_invalid_build_dir "${_tip_case_root}/${name}-build")
  file(MAKE_DIRECTORY "${_tip_invalid_source_dir}")
  file(WRITE "${_tip_invalid_source_dir}/CMakeLists.txt" "cmake_minimum_required(VERSION 3.25)\n" "project(proof_${name} VERSION 1.0.0 LANGUAGES NONE)\n"
                                                         "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n" "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n" "${invocation}\n")
  _tip_proof_expect_failure(
    NAME
    "${name}"
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${_tip_invalid_source_dir}"
    -B
    "${_tip_invalid_build_dir}"
    ${_tip_toolchain_args}
    EXPECT_CONTAINS
    "${expected}")
endfunction()

_tip_write_invalid_fixture("checksum-conflict" "export_cpack(GENERATORS TGZ CHECKSUMS SHA256 GENERATE_CHECKSUMS ON)" "cannot be used together")
_tip_write_invalid_fixture("checksum-invalid" "export_cpack(GENERATORS TGZ CHECKSUMS BLAKE3)" "'BLAKE3'.  Supported values")

message(STATUS "[proof] CPack checksum proof passed.")
