CMAKE_MINIMUM_REQUIRED(VERSION 4.3)

INCLUDE("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

IF(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
ENDIF()
IF(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
ENDIF()
IF(NOT CMAKE_CPACK_COMMAND)
  _tip_proof_fail("CMAKE_CPACK_COMMAND is required")
ENDIF()

SET(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-compression")
FILE(REMOVE_RECURSE "${_tip_case_root}")
FILE(MAKE_DIRECTORY "${_tip_case_root}")
_tip_proof_append_toolchain_args(_tip_toolchain_args)

FUNCTION(_tip_write_compression_fixture name invocation)
  SET(_tip_source_dir "${_tip_case_root}/${name}-src")
  FILE(MAKE_DIRECTORY "${_tip_source_dir}")
  FILE(WRITE "${_tip_source_dir}/payload.txt" "compression proof\n")
  FILE(WRITE "${_tip_source_dir}/CMakeLists.txt" "CMAKE_MINIMUM_REQUIRED(VERSION 3.25)\n" "PROJECT(proof_${name} VERSION 1.0.0 LANGUAGES NONE)\n" "SET(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
                                                 "INCLUDE(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n" "INSTALL(FILES payload.txt DESTINATION share/proof)\n" "${invocation}\n")
ENDFUNCTION()

FUNCTION(_tip_configure_compression_fixture name invocation)
  _tip_write_compression_fixture("${name}" "${invocation}")
  _tip_proof_run_step(
    NAME
    "configure-${name}"
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${_tip_case_root}/${name}-src"
    -B
    "${_tip_case_root}/${name}-build"
    ${_tip_toolchain_args})
ENDFUNCTION()

_tip_configure_compression_fixture(
  "archive"
  "export_cpack(PACKAGE_NAME ProofArchiveCompression PACKAGE_VERSION 1.0.0 GENERATORS TGZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 ARCHIVE_COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_ARCHIVE_COMPRESSION_LEVEL 8)"
)
SET(_tip_archive_config "${_tip_case_root}/archive-build/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_archive_config}" "set(CPACK_COMPRESSION_LEVEL \"19\")")
_tip_proof_assert_file_contains("${_tip_archive_config}" "set(CPACK_ARCHIVE_COMPRESSION_LEVEL \"8\")")

SET(_tip_archive_package_dir "${_tip_case_root}/archive-packages")
_tip_proof_run_step(
  NAME
  "package-archive"
  COMMAND
  "${CMAKE_CPACK_COMMAND}"
  -G
  TGZ
  --config
  "${_tip_archive_config}"
  -B
  "${_tip_archive_package_dir}")
FILE(GLOB _tip_archive_packages "${_tip_archive_package_dir}/*.tar.gz")
LIST(LENGTH _tip_archive_packages _tip_archive_package_count)
IF(_tip_archive_package_count EQUAL 0)
  _tip_proof_fail("Expected at least one TGZ package")
ENDIF()

_tip_configure_compression_fixture(
  "zstd-archive"
  "export_cpack(PACKAGE_NAME ProofZstdArchive PACKAGE_VERSION 1.0.0 GENERATORS TZST NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 ARCHIVE_COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR TZST)"
)
SET(_tip_zstd_archive_config "${_tip_case_root}/zstd-archive-build/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_zstd_archive_config}" "set(CPACK_COMPRESSION_LEVEL \"19\")")
_tip_proof_assert_file_contains("${_tip_zstd_archive_config}" "set(CPACK_ARCHIVE_COMPRESSION_LEVEL \"19\")")
SET(_tip_zstd_source_config "${_tip_case_root}/zstd-archive-build/CPackSourceConfig.cmake")
_tip_proof_assert_file_contains("${_tip_zstd_source_config}" "set(CPACK_SOURCE_GENERATOR \"TZST\")")
_tip_proof_assert_file_contains("${_tip_zstd_source_config}" "set(CPACK_COMPRESSION_LEVEL \"19\")")
_tip_proof_assert_file_contains("${_tip_zstd_source_config}" "set(CPACK_ARCHIVE_COMPRESSION_LEVEL \"19\")")

SET(_tip_zstd_archive_package_dir "${_tip_case_root}/zstd-archive-packages")
_tip_proof_run_step(
  NAME
  "package-zstd-archive"
  COMMAND
  "${CMAKE_CPACK_COMMAND}"
  -G
  TZST
  --config
  "${_tip_zstd_archive_config}"
  -B
  "${_tip_zstd_archive_package_dir}")
FILE(GLOB _tip_zstd_archive_packages "${_tip_zstd_archive_package_dir}/*.tar.zst")
LIST(LENGTH _tip_zstd_archive_packages _tip_zstd_archive_package_count)
IF(_tip_zstd_archive_package_count EQUAL 0)
  _tip_proof_fail("Expected at least one binary TZST package")
ENDIF()

SET(_tip_zstd_source_package_dir "${_tip_case_root}/zstd-source-packages")
_tip_proof_run_step(
  NAME
  "package-zstd-source"
  COMMAND
  "${CMAKE_CPACK_COMMAND}"
  -G
  TZST
  --config
  "${_tip_zstd_source_config}"
  -B
  "${_tip_zstd_source_package_dir}")
FILE(GLOB _tip_zstd_source_packages "${_tip_zstd_source_package_dir}/*.tar.zst")
LIST(LENGTH _tip_zstd_source_packages _tip_zstd_source_package_count)
IF(_tip_zstd_source_package_count EQUAL 0)
  _tip_proof_fail("Expected at least one source TZST package")
ENDIF()

_tip_configure_compression_fixture("stgz" "export_cpack(PACKAGE_NAME ProofStgzCompression PACKAGE_VERSION 1.0.0 GENERATORS STGZ NO_DEFAULT_GENERATORS ARCHIVE_COMPRESSION_LEVEL 9)")
SET(_tip_stgz_config "${_tip_case_root}/stgz-build/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_stgz_config}" "set(CPACK_GENERATOR \"STGZ\")")
_tip_proof_assert_file_contains("${_tip_stgz_config}" "set(CPACK_ARCHIVE_COMPRESSION_LEVEL \"9\")")

_tip_configure_compression_fixture("defaults" "export_cpack(PACKAGE_NAME ProofCompressionDefaults PACKAGE_VERSION 1.0.0 GENERATORS TGZ NO_DEFAULT_GENERATORS)")
SET(_tip_defaults_config "${_tip_case_root}/defaults-build/CPackConfig.cmake")
_tip_proof_assert_file_not_contains("${_tip_defaults_config}" "CPACK_ARCHIVE_COMPRESSION_LEVEL")
_tip_proof_assert_file_not_contains("${_tip_defaults_config}" "CPACK_DEBIAN_COMPRESSION_LEVEL")

_tip_configure_compression_fixture(
  "generic-additional-override"
  "export_cpack(PACKAGE_NAME ProofGenericOverride PACKAGE_VERSION 1.0.0 GENERATORS TGZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_COMPRESSION_LEVEL 8)")
SET(_tip_generic_override_config "${_tip_case_root}/generic-additional-override-build/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_generic_override_config}" "set(CPACK_COMPRESSION_LEVEL \"8\")")

_tip_configure_compression_fixture(
  "generator-additional-override"
  "export_cpack(PACKAGE_NAME ProofGeneratorOverride PACKAGE_VERSION 1.0.0 GENERATORS TGZ NO_DEFAULT_GENERATORS ARCHIVE_COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_GENERATOR TZST CPACK_SOURCE_GENERATOR TZST)"
)
SET(_tip_generator_override_config "${_tip_case_root}/generator-additional-override-build/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_generator_override_config}" "set(CPACK_GENERATOR \"TZST\")")
_tip_proof_assert_file_contains("${_tip_generator_override_config}" "set(CPACK_ARCHIVE_COMPRESSION_LEVEL \"19\")")

_tip_configure_compression_fixture(
  "native-binary-selector"
  [=[
SET(CPACK_BINARY_7Z OFF)
SET(CPACK_BINARY_BUNDLE OFF)
SET(CPACK_BINARY_CYGWIN OFF)
SET(CPACK_BINARY_DEB OFF)
SET(CPACK_BINARY_DRAGNDROP OFF)
SET(CPACK_BINARY_FREEBSD OFF)
SET(CPACK_BINARY_IFW OFF)
SET(CPACK_BINARY_NSIS OFF)
SET(CPACK_BINARY_INNOSETUP OFF)
SET(CPACK_BINARY_NUGET OFF)
SET(CPACK_BINARY_PRODUCTBUILD OFF)
SET(CPACK_BINARY_RPM OFF)
SET(CPACK_BINARY_STGZ OFF)
SET(CPACK_BINARY_TBZ2 OFF)
SET(CPACK_BINARY_TGZ OFF)
SET(CPACK_BINARY_TXZ OFF)
SET(CPACK_BINARY_TZ OFF)
SET(CPACK_BINARY_WIX OFF)
SET(CPACK_BINARY_ZIP OFF)
export_cpack(PACKAGE_NAME ProofNativeBinarySelector PACKAGE_VERSION 1.0.0 NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 9 ADDITIONAL_CPACK_VARS CPACK_GENERATOR "" CPACK_BINARY_TGZ OFF CPACK_BINARY_TGZ ON CPACK_SOURCE_GENERATOR TZST)
]=])
SET(_tip_native_binary_selector_config "${_tip_case_root}/native-binary-selector-build/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_native_binary_selector_config}" "set(CPACK_GENERATOR \"TGZ\")")
SET(_tip_native_binary_selector_package_dir "${_tip_case_root}/native-binary-selector-packages")
_tip_proof_run_step(
  NAME
  "package-native-binary-selector"
  COMMAND
  "${CMAKE_CPACK_COMMAND}"
  --config
  "${_tip_native_binary_selector_config}"
  -B
  "${_tip_native_binary_selector_package_dir}")
FILE(GLOB _tip_native_binary_selector_packages "${_tip_native_binary_selector_package_dir}/*.tar.gz")
LIST(LENGTH _tip_native_binary_selector_packages _tip_native_binary_selector_package_count)
IF(_tip_native_binary_selector_package_count EQUAL 0)
  _tip_proof_fail("Expected a native-selector TGZ package")
ENDIF()

_tip_configure_compression_fixture(
  "neutral-archives"
  [=[
SET(CPACK_SOURCE_7Z OFF)
SET(CPACK_SOURCE_CYGWIN OFF)
SET(CPACK_SOURCE_RPM OFF)
SET(CPACK_SOURCE_TBZ2 OFF)
SET(CPACK_SOURCE_TGZ ON)
SET(CPACK_SOURCE_TXZ OFF)
SET(CPACK_SOURCE_TZ ON)
SET(CPACK_SOURCE_ZIP OFF)
export_cpack(PACKAGE_NAME ProofNeutralArchives PACKAGE_VERSION 1.0.0 GENERATORS TZST TAR TZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 ARCHIVE_COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR "" CPACK_SOURCE_TGZ ON CPACK_SOURCE_TGZ OFF)
]=])
SET(_tip_neutral_archive_config "${_tip_case_root}/neutral-archives-build/CPackConfig.cmake")
SET(_tip_neutral_source_config "${_tip_case_root}/neutral-archives-build/CPackSourceConfig.cmake")
_tip_proof_assert_file_contains("${_tip_neutral_archive_config}" "set(CPACK_GENERATOR \"TZST;TAR;TZ\")")
_tip_proof_assert_file_contains("${_tip_neutral_source_config}" "set(CPACK_GENERATOR \"TZ\")")
SET(_tip_neutral_archive_package_dir "${_tip_case_root}/neutral-archive-packages")
_tip_proof_run_step(
  NAME
  "package-neutral-archives"
  COMMAND
  "${CMAKE_CPACK_COMMAND}"
  --config
  "${_tip_neutral_archive_config}"
  -B
  "${_tip_neutral_archive_package_dir}")
FOREACH(_tip_neutral_archive_pattern "*.tar.zst" "*.tar" "*.tar.Z")
  FILE(GLOB _tip_neutral_archive_packages "${_tip_neutral_archive_package_dir}/${_tip_neutral_archive_pattern}")
  LIST(LENGTH _tip_neutral_archive_packages _tip_neutral_archive_package_count)
  IF(_tip_neutral_archive_package_count EQUAL 0)
    _tip_proof_fail("Expected a '${_tip_neutral_archive_pattern}' package")
  ENDIF()
ENDFOREACH()
SET(_tip_neutral_source_package_dir "${_tip_case_root}/neutral-source-packages")
_tip_proof_run_step(
  NAME
  "package-neutral-source-selector"
  COMMAND
  "${CMAKE_CPACK_COMMAND}"
  --config
  "${_tip_neutral_source_config}"
  -B
  "${_tip_neutral_source_package_dir}")
FILE(GLOB _tip_neutral_source_packages "${_tip_neutral_source_package_dir}/*.tar.Z")
LIST(LENGTH _tip_neutral_source_packages _tip_neutral_source_package_count)
IF(_tip_neutral_source_package_count EQUAL 0)
  _tip_proof_fail("Expected a selector-derived TZ source package")
ENDIF()

_tip_configure_compression_fixture(
  "additional-keyword-value"
  "export_cpack(PACKAGE_NAME ProofAdditionalKeywordValue PACKAGE_VERSION 1.0.0 GENERATORS TGZ NO_DEFAULT_GENERATORS ADDITIONAL_CPACK_VARS CPACK_PACKAGE_DESCRIPTION COMPRESSION_LEVEL PACKAGE_VENDOR KeywordValueVendor)"
)
SET(_tip_additional_keyword_config "${_tip_case_root}/additional-keyword-value-build/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_additional_keyword_config}" "set(CPACK_PACKAGE_DESCRIPTION \"COMPRESSION_LEVEL\")")
_tip_proof_assert_file_contains("${_tip_additional_keyword_config}" "set(CPACK_PACKAGE_VENDOR \"KeywordValueVendor\")")

IF(TIP_TEST_DEB)
  _tip_configure_compression_fixture(
    "debian" "export_cpack(PACKAGE_NAME ProofDebianCompression PACKAGE_VERSION 1.0.0 GENERATORS DEB NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 2 DEBIAN_COMPRESSION_TYPE xz DEBIAN_COMPRESSION_LEVEL 9)")
  SET(_tip_debian_config "${_tip_case_root}/debian-build/CPackConfig.cmake")
  _tip_proof_assert_file_contains("${_tip_debian_config}" "set(CPACK_COMPRESSION_LEVEL \"2\")")
  _tip_proof_assert_file_contains("${_tip_debian_config}" "set(CPACK_DEBIAN_COMPRESSION_TYPE \"xz\")")
  _tip_proof_assert_file_contains("${_tip_debian_config}" "set(CPACK_DEBIAN_COMPRESSION_LEVEL \"9\")")

  SET(_tip_debian_package_dir "${_tip_case_root}/debian-packages")
  _tip_proof_run_step(
    NAME
    "package-debian"
    COMMAND
    "${CMAKE_CPACK_COMMAND}"
    -G
    DEB
    --config
    "${_tip_debian_config}"
    -B
    "${_tip_debian_package_dir}")
  FILE(GLOB _tip_debian_packages "${_tip_debian_package_dir}/*.deb")
  LIST(LENGTH _tip_debian_packages _tip_debian_package_count)
  IF(_tip_debian_package_count EQUAL 0)
    _tip_proof_fail("Expected at least one DEB package")
  ENDIF()

  FIND_PROGRAM(_tip_ar_command NAMES ar llvm-ar)
  IF(_tip_ar_command)
    LIST(GET _tip_debian_packages 0 _tip_debian_package)
    EXECUTE_PROCESS(
      COMMAND "${_tip_ar_command}" t "${_tip_debian_package}"
      RESULT_VARIABLE _tip_ar_result
      OUTPUT_VARIABLE _tip_debian_members
      ERROR_VARIABLE _tip_ar_error)
    IF(NOT _tip_ar_result EQUAL 0)
      _tip_proof_fail("Could not inspect Debian package: ${_tip_ar_error}")
    ENDIF()
    STRING(FIND "${_tip_debian_members}" "data.tar.xz" _tip_data_member_index)
    IF(_tip_data_member_index EQUAL -1)
      _tip_proof_fail("Expected xz-compressed Debian data archive, got: ${_tip_debian_members}")
    ENDIF()
  ENDIF()

  _tip_configure_compression_fixture("zstd-debian"
                                     "export_cpack(PACKAGE_NAME ProofZstdDebian PACKAGE_VERSION 1.0.0 GENERATORS DEB NO_DEFAULT_GENERATORS DEBIAN_COMPRESSION_TYPE zstd DEBIAN_COMPRESSION_LEVEL 19)")

  _tip_configure_compression_fixture(
    "source-only-zstd-debian"
    "export_cpack(PACKAGE_NAME ProofSourceZstdDebian PACKAGE_VERSION 1.0.0 GENERATORS RPM NO_DEFAULT_GENERATORS DEBIAN_COMPRESSION_TYPE zstd DEBIAN_COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR DEB)"
  )
  SET(_tip_source_debian_config "${_tip_case_root}/source-only-zstd-debian-build/CPackSourceConfig.cmake")
  _tip_proof_assert_file_contains("${_tip_source_debian_config}" "set(CPACK_GENERATOR \"DEB\")")
  _tip_proof_assert_file_contains("${_tip_source_debian_config}" "set(CPACK_DEBIAN_COMPRESSION_TYPE \"zstd\")")
  _tip_proof_assert_file_contains("${_tip_source_debian_config}" "set(CPACK_DEBIAN_COMPRESSION_LEVEL \"19\")")
  SET(_tip_source_debian_package_dir "${_tip_case_root}/source-only-zstd-debian-packages")
  _tip_proof_run_step(
    NAME
    "package-source-only-zstd-debian"
    COMMAND
    "${CMAKE_CPACK_COMMAND}"
    --config
    "${_tip_source_debian_config}"
    -B
    "${_tip_source_debian_package_dir}")
  FILE(GLOB _tip_source_debian_packages "${_tip_source_debian_package_dir}/*.deb")
  LIST(LENGTH _tip_source_debian_packages _tip_source_debian_package_count)
  IF(_tip_source_debian_package_count EQUAL 0)
    _tip_proof_fail("Expected a source-only DEB package")
  ENDIF()
  IF(_tip_ar_command)
    LIST(GET _tip_source_debian_packages 0 _tip_source_debian_package)
    EXECUTE_PROCESS(
      COMMAND "${_tip_ar_command}" t "${_tip_source_debian_package}"
      RESULT_VARIABLE _tip_source_ar_result
      OUTPUT_VARIABLE _tip_source_debian_members
      ERROR_VARIABLE _tip_source_ar_error)
    IF(NOT _tip_source_ar_result EQUAL 0)
      _tip_proof_fail("Could not inspect source-only Debian package: ${_tip_source_ar_error}")
    ENDIF()
    STRING(FIND "${_tip_source_debian_members}" "data.tar.zst" _tip_source_data_member_index)
    IF(_tip_source_data_member_index EQUAL -1)
      _tip_proof_fail("Expected zstd-compressed source-only Debian data archive, got: ${_tip_source_debian_members}")
    ENDIF()
  ENDIF()

  _tip_configure_compression_fixture(
    "debian-additional-overrides"
    [=[
export_cpack(
  PACKAGE_NAME ProofDebianOverrides
  PACKAGE_VERSION 1.0.0
  GENERATORS DEB
  NO_DEFAULT_GENERATORS
  COMPRESSION_LEVEL 19
  DEBIAN_COMPRESSION_TYPE brotli
  DEBIAN_COMPRESSION_LEVEL 20
  ADDITIONAL_CPACK_VARS
    CPACK_DEBIAN_COMPRESSION_TYPE xz
    CPACK_DEBIAN_COMPRESSION_LEVEL 8
    CPACK_SOURCE_GENERATOR TZST)
]=]
  )
  SET(_tip_debian_overrides_config "${_tip_case_root}/debian-additional-overrides-build/CPackConfig.cmake")
  _tip_proof_assert_file_contains("${_tip_debian_overrides_config}" "set(CPACK_DEBIAN_COMPRESSION_TYPE \"xz\")")
  _tip_proof_assert_file_contains("${_tip_debian_overrides_config}" "set(CPACK_DEBIAN_COMPRESSION_LEVEL \"8\")")
ENDIF()

FUNCTION(_tip_expect_invalid_compression name invocation expected)
  _tip_write_compression_fixture("${name}" "${invocation}")
  EXECUTE_PROCESS(
    COMMAND "${CMAKE_COMMAND}" -S "${_tip_case_root}/${name}-src" -B "${_tip_case_root}/${name}-build" ${_tip_toolchain_args}
    RESULT_VARIABLE _tip_result
    OUTPUT_VARIABLE _tip_stdout
    ERROR_VARIABLE _tip_stderr)
  IF(_tip_result EQUAL 0)
    _tip_proof_fail("Invalid compression fixture '${name}' unexpectedly succeeded")
  ENDIF()
  SET(_tip_output "${_tip_stdout}\n${_tip_stderr}")
  STRING(REGEX REPLACE "[ \t\r\n]+" " " _tip_output "${_tip_output}")
  STRING(FIND "${_tip_output}" "${expected}" _tip_expected_index)
  IF(_tip_expected_index EQUAL -1)
    _tip_proof_fail("Expected '${expected}' in normalized output of '${name}': ${_tip_output}")
  ENDIF()
ENDFUNCTION()

_tip_expect_invalid_compression("non-integer" "export_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL fast)" "must be an integer from 0 to 9")
_tip_expect_invalid_compression("negative" "export_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL -1)" "must be an integer from 0 to 9")
_tip_expect_invalid_compression("generic-range" "export_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 10)" "must be an integer from 0 to 9")
_tip_expect_invalid_compression("source-range" "export_cpack(GENERATORS TZST NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19)" "must be an integer from 0 to 9")
_tip_expect_invalid_compression("debian-source-range" "export_cpack(GENERATORS RPM NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR DEB)"
                                "must be an integer from 0 to 9")
_tip_expect_invalid_compression(
  "generator-override-range" "export_cpack(GENERATORS TZST NO_DEFAULT_GENERATORS ARCHIVE_COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_GENERATOR TGZ CPACK_SOURCE_GENERATOR TZST)"
  "must be an integer from 0 to 9")
_tip_expect_invalid_compression("mixed-archive-range" "export_cpack(GENERATORS TGZ TZST NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 10)" "must be an integer from 0 to 9")
_tip_expect_invalid_compression("zip-zstd-range" "export_cpack(GENERATORS ZIP_ZSTD NO_DEFAULT_GENERATORS ARCHIVE_COMPRESSION_LEVEL 10)" "must be an integer from 0 to 9")
_tip_expect_invalid_compression("zstd-source-range" "export_cpack(GENERATORS TZST NO_DEFAULT_GENERATORS ARCHIVE_COMPRESSION_LEVEL 10)" "must be an integer from 0 to 9")
_tip_expect_invalid_compression("zstd-range" "export_cpack(GENERATORS TZST NO_DEFAULT_GENERATORS ARCHIVE_COMPRESSION_LEVEL 20 ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR TZST)"
                                "must be an integer from 0 to 19")
_tip_expect_invalid_compression("zip-store-range" "export_cpack(GENERATORS ZIP_STORE NO_DEFAULT_GENERATORS ARCHIVE_COMPRESSION_LEVEL 10 ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR TZST)"
                                "must be an integer from 0 to 9")
_tip_expect_invalid_compression("7z-store-range" "export_cpack(GENERATORS 7Z_STORE NO_DEFAULT_GENERATORS ARCHIVE_COMPRESSION_LEVEL 10 ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR TZST)"
                                "must be an integer from 0 to 9")
_tip_expect_invalid_compression(
  "native-binary-selector-range"
  "SET(CPACK_GENERATOR OFF)\nSET(CPACK_BINARY_STGZ OFF)\nSET(CPACK_BINARY_TGZ ON)\nSET(CPACK_BINARY_TZ OFF)\nexport_cpack(NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR TZST)"
  "must be an integer from 0 to 9")
_tip_expect_invalid_compression(
  "ambient-archive-empty" "SET(CPACK_ARCHIVE_COMPRESSION_LEVEL \"\")\nexport_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR TZST)"
  "must be an integer from 0 to 9")
_tip_expect_invalid_compression(
  "ambient-archive-notfound"
  "SET(CPACK_ARCHIVE_COMPRESSION_LEVEL archive-level-NOTFOUND)\nexport_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR TZST)"
  "must be an integer from 0 to 9")
_tip_expect_invalid_compression(
  "ambient-archive-exact-notfound"
  "SET(CPACK_ARCHIVE_COMPRESSION_LEVEL NOTFOUND)\nexport_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR TZST)"
  "must be an integer from 0 to 9")
_tip_expect_invalid_compression(
  "repeated-archive-final-empty"
  "export_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 ARCHIVE_COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_ARCHIVE_COMPRESSION_LEVEL 9 CPACK_ARCHIVE_COMPRESSION_LEVEL \"\" CPACK_SOURCE_GENERATOR TZST)"
  "must be an integer from 0 to 9")
_tip_expect_invalid_compression(
  "ambient-debian-empty"
  "SET(CPACK_DEBIAN_COMPRESSION_LEVEL \"\")\nexport_cpack(GENERATORS DEB NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 DEBIAN_COMPRESSION_TYPE gzip ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR TZST)"
  "must be an integer from 0 to 9")
_tip_expect_invalid_compression(
  "ambient-debian-notfound"
  "SET(CPACK_DEBIAN_COMPRESSION_LEVEL debian-level-NOTFOUND)\nexport_cpack(GENERATORS DEB NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 DEBIAN_COMPRESSION_TYPE gzip ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR TZST)"
  "must be an integer from 0 to 9")
_tip_expect_invalid_compression(
  "ambient-debian-exact-notfound"
  "SET(CPACK_DEBIAN_COMPRESSION_LEVEL NOTFOUND)\nexport_cpack(GENERATORS DEB NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 19 DEBIAN_COMPRESSION_TYPE gzip ADDITIONAL_CPACK_VARS CPACK_SOURCE_GENERATOR TZST)"
  "must be an integer from 0 to 9")
_tip_expect_invalid_compression(
  "repeated-debian-final-empty"
  [=[
export_cpack(
  GENERATORS DEB
  NO_DEFAULT_GENERATORS
  COMPRESSION_LEVEL 19
  DEBIAN_COMPRESSION_TYPE gzip
  DEBIAN_COMPRESSION_LEVEL 9
  ADDITIONAL_CPACK_VARS
    CPACK_DEBIAN_COMPRESSION_LEVEL 8
    CPACK_DEBIAN_COMPRESSION_LEVEL ""
    CPACK_SOURCE_GENERATOR TZST)
]=]
  "must be an integer from 0 to 9")
_tip_expect_invalid_compression(
  "repeated-debian-final-notfound"
  [=[
export_cpack(
  GENERATORS DEB
  NO_DEFAULT_GENERATORS
  COMPRESSION_LEVEL 19
  DEBIAN_COMPRESSION_TYPE gzip
  DEBIAN_COMPRESSION_LEVEL 9
  ADDITIONAL_CPACK_VARS
    CPACK_DEBIAN_COMPRESSION_LEVEL 8
    CPACK_DEBIAN_COMPRESSION_LEVEL debian-level-NOTFOUND
    CPACK_SOURCE_GENERATOR TZST)
]=]
  "must be an integer from 0 to 9")
_tip_expect_invalid_compression("huge-level" "export_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL 999999999999999999999999999999999999)" "must be an integer from 0 to 9")
_tip_expect_invalid_compression("archive-generator" "export_cpack(GENERATORS DEB NO_DEFAULT_GENERATORS ARCHIVE_COMPRESSION_LEVEL 1)" "requires an archive generator")
_tip_expect_invalid_compression("debian-generator" "export_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS DEBIAN_COMPRESSION_LEVEL 1)" "requires the DEB generator")
_tip_expect_invalid_compression("debian-algorithm" "export_cpack(GENERATORS DEB NO_DEFAULT_GENERATORS DEBIAN_COMPRESSION_TYPE brotli)" "Unsupported DEBIAN_COMPRESSION_TYPE 'brotli'")
_tip_expect_invalid_compression("debian-range" "export_cpack(GENERATORS DEB NO_DEFAULT_GENERATORS DEBIAN_COMPRESSION_LEVEL 10)" "must be an integer from 0 to 9")
_tip_expect_invalid_compression(
  "debian-type-override-range" "export_cpack(GENERATORS DEB NO_DEFAULT_GENERATORS DEBIAN_COMPRESSION_LEVEL 19 ADDITIONAL_CPACK_VARS CPACK_DEBIAN_COMPRESSION_TYPE gzip CPACK_SOURCE_GENERATOR DEB)"
  "must be an integer from 0 to 9")
_tip_expect_invalid_compression("debian-generator-override" "export_cpack(GENERATORS DEB NO_DEFAULT_GENERATORS DEBIAN_COMPRESSION_LEVEL 1 ADDITIONAL_CPACK_VARS CPACK_GENERATOR TGZ)"
                                "requires the DEB generator")
_tip_expect_invalid_compression("missing-level" "export_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS COMPRESSION_LEVEL)" "COMPRESSION_LEVEL requires a value")

MESSAGE(STATUS "[proof] CPack compression proof passed.")
