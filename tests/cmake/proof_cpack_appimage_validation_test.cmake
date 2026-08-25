CMAKE_MINIMUM_REQUIRED(VERSION 4.2)

INCLUDE("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

IF(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
ENDIF()
IF(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
ENDIF()
IF(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
  _tip_proof_fail("The AppImage validation proof requires a Linux host")
ENDIF()

SET(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-appimage-validation")
FILE(REMOVE_RECURSE "${_tip_case_root}")
FILE(MAKE_DIRECTORY "${_tip_case_root}")
_tip_proof_append_toolchain_args(_tip_toolchain_args)

FUNCTION(_tip_write_appimage_fixture name desktop_variant export_call)
  SET(options OMIT_METADATA_INSTALL SPOOF_NON_LINUX_HOST)
  CMAKE_PARSE_ARGUMENTS(ARG "${options}" "" "" ${ARGN})

  SET(_tip_source_dir "${_tip_case_root}/${name}-src")
  SET(_tip_build_dir "${_tip_case_root}/${name}-build")
  FILE(MAKE_DIRECTORY "${_tip_source_dir}/fake-bin")

  SET(_tip_desktop_entry "[Desktop Entry]\nType=Application\nName=AppImage validation proof\nExec=proof-app\nIcon=proof-app\nCategories=Development;\nTerminal=true\n")
  IF(desktop_variant STREQUAL "missing-section")
    SET(_tip_desktop_entry "Type=Application\nExec=proof-app\nIcon=proof-app\n")
  ELSEIF(desktop_variant STREQUAL "bad-type")
    SET(_tip_desktop_entry "[Desktop Entry]\nType=Link\nName=AppImage validation proof\nExec=proof-app\nIcon=proof-app\n")
  ELSEIF(desktop_variant STREQUAL "missing-icon")
    SET(_tip_desktop_entry "[Desktop Entry]\nType=Application\nName=AppImage validation proof\nExec=proof-app\n")
  ELSEIF(desktop_variant STREQUAL "mismatched-icon")
    SET(_tip_desktop_entry "[Desktop Entry]\nType=Application\nName=AppImage validation proof\nExec=proof-app\nIcon=other-app\n")
  ELSEIF(desktop_variant STREQUAL "missing-exec")
    SET(_tip_desktop_entry "[Desktop Entry]\nType=Application\nName=AppImage validation proof\nIcon=proof-app\n")
  ENDIF()

  FILE(WRITE "${_tip_source_dir}/proof.desktop" "${_tip_desktop_entry}")
  FILE(WRITE "${_tip_source_dir}/proof.txt" "not an icon\n")
  FILE(WRITE "${_tip_source_dir}/proof-app.svg" "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><rect width=\"16\" height=\"16\"/></svg>\n")
  FILE(WRITE "${_tip_source_dir}/payload.txt" "AppImage validation payload\n")
  FOREACH(_tip_fake_tool IN ITEMS appimagetool patchelf)
    FILE(WRITE "${_tip_source_dir}/fake-bin/${_tip_fake_tool}" "#!/bin/sh\nexit 0\n")
  ENDFOREACH()
  FILE(
    CHMOD
    "${_tip_source_dir}/fake-bin/appimagetool"
    "${_tip_source_dir}/fake-bin/patchelf"
    PERMISSIONS
    OWNER_READ
    OWNER_WRITE
    OWNER_EXECUTE
    GROUP_READ
    GROUP_EXECUTE
    WORLD_READ
    WORLD_EXECUTE)

  SET(_tip_host_override "")
  IF(ARG_SPOOF_NON_LINUX_HOST)
    SET(_tip_host_override "SET(CMAKE_HOST_SYSTEM_NAME Darwin)\n")
  ENDIF()
  SET(_tip_metadata_install "")
  IF(NOT ARG_OMIT_METADATA_INSTALL)
    SET(_tip_metadata_install
        "INSTALL(FILES proof.desktop DESTINATION share/applications COMPONENT Runtime)\nINSTALL(FILES proof-app.svg DESTINATION share/icons/hicolor/scalable/apps COMPONENT Runtime)\n")
  ENDIF()

  FILE(
    WRITE "${_tip_source_dir}/CMakeLists.txt"
    "CMAKE_MINIMUM_REQUIRED(VERSION 3.25)\n"
    "PROJECT(proof_${name} VERSION 1.0.0 LANGUAGES NONE)\n"
    "${_tip_host_override}"
    "INCLUDE(\"${TIP_REPO_ROOT}/export_cpack.cmake\")\n"
    "INSTALL(FILES payload.txt DESTINATION share/proof COMPONENT Documentation)\n"
    "${_tip_metadata_install}"
    "${export_call}\n")

  SET(_tip_fixture_source_dir
      "${_tip_source_dir}"
      PARENT_SCOPE)
  SET(_tip_fixture_build_dir
      "${_tip_build_dir}"
      PARENT_SCOPE)
ENDFUNCTION()

FUNCTION(_tip_expect_appimage_configure_failure name desktop_variant expected export_call)
  _tip_write_appimage_fixture("${name}" "${desktop_variant}" "${export_call}" ${ARGN})
  _tip_proof_expect_failure(
    NAME
    "${name}"
    COMMAND
    "${CMAKE_COMMAND}"
    -S
    "${_tip_fixture_source_dir}"
    -B
    "${_tip_fixture_build_dir}"
    ${_tip_toolchain_args}
    EXPECT_CONTAINS
    "${expected}")
ENDFUNCTION()

SET(_tip_valid_export_call
    "export_cpack(PACKAGE_NAME ProofAppImage GENERATORS AppImage COMPONENTS Runtime Development Documentation APPIMAGE_DESKTOP_FILE proof.desktop APPIMAGE_ICON_FILE proof-app.svg APPIMAGE_TOOL_EXECUTABLE fake-bin/appimagetool APPIMAGE_PATCHELF_EXECUTABLE fake-bin/patchelf)"
)

_tip_expect_appimage_configure_failure("unsupported-host" "valid" "got Darwin" "${_tip_valid_export_call}" SPOOF_NON_LINUX_HOST)
_tip_expect_appimage_configure_failure(
  "missing-desktop-argument" "valid" "APPIMAGE_DESKTOP_FILE pointing"
  "export_cpack(GENERATORS AppImage APPIMAGE_ICON_FILE proof-app.svg APPIMAGE_TOOL_EXECUTABLE fake-bin/appimagetool APPIMAGE_PATCHELF_EXECUTABLE fake-bin/patchelf)")
_tip_expect_appimage_configure_failure(
  "missing-icon-argument" "valid" "APPIMAGE_ICON_FILE"
  "export_cpack(GENERATORS AppImage APPIMAGE_DESKTOP_FILE proof.desktop APPIMAGE_TOOL_EXECUTABLE fake-bin/appimagetool APPIMAGE_PATCHELF_EXECUTABLE fake-bin/patchelf)")
_tip_expect_appimage_configure_failure(
  "missing-desktop-file"
  "valid"
  "must name an existing"
  "export_cpack(GENERATORS AppImage APPIMAGE_DESKTOP_FILE missing.desktop APPIMAGE_ICON_FILE proof-app.svg APPIMAGE_TOOL_EXECUTABLE fake-bin/appimagetool APPIMAGE_PATCHELF_EXECUTABLE fake-bin/patchelf)"
)
_tip_expect_appimage_configure_failure(
  "invalid-icon-extension" "valid" ".xpm extension"
  "export_cpack(GENERATORS AppImage APPIMAGE_DESKTOP_FILE proof.desktop APPIMAGE_ICON_FILE proof.txt APPIMAGE_TOOL_EXECUTABLE fake-bin/appimagetool APPIMAGE_PATCHELF_EXECUTABLE fake-bin/patchelf)")
_tip_expect_appimage_configure_failure("missing-desktop-section" "missing-section" "must contain a [Desktop" "${_tip_valid_export_call}")
_tip_expect_appimage_configure_failure("invalid-desktop-type" "bad-type" "Type=Application" "${_tip_valid_export_call}")
_tip_expect_appimage_configure_failure("missing-desktop-icon" "missing-icon" "non-empty Icon" "${_tip_valid_export_call}")
_tip_expect_appimage_configure_failure("mismatched-desktop-icon" "mismatched-icon" "prefix-match" "${_tip_valid_export_call}")
_tip_expect_appimage_configure_failure("missing-desktop-exec" "missing-exec" "non-empty Exec" "${_tip_valid_export_call}")
_tip_expect_appimage_configure_failure(
  "missing-appimagetool" "valid" "APPIMAGE_TOOL_EXECUTABLE"
  "export_cpack(GENERATORS AppImage APPIMAGE_DESKTOP_FILE proof.desktop APPIMAGE_ICON_FILE proof-app.svg APPIMAGE_TOOL_EXECUTABLE missing/appimagetool APPIMAGE_PATCHELF_EXECUTABLE fake-bin/patchelf)")
_tip_expect_appimage_configure_failure(
  "missing-patchelf" "valid" "APPIMAGE_PATCHELF_EXECUTABLE"
  "export_cpack(GENERATORS AppImage APPIMAGE_DESKTOP_FILE proof.desktop APPIMAGE_ICON_FILE proof-app.svg APPIMAGE_TOOL_EXECUTABLE fake-bin/appimagetool APPIMAGE_PATCHELF_EXECUTABLE missing/patchelf)")
_tip_expect_appimage_configure_failure(
  "missing-tool-override-value" "valid" "requires a value"
  "export_cpack(GENERATORS AppImage APPIMAGE_DESKTOP_FILE proof.desktop APPIMAGE_ICON_FILE proof-app.svg APPIMAGE_TOOL_EXECUTABLE fake-bin/appimagetool APPIMAGE_PATCHELF_EXECUTABLE)")
_tip_expect_appimage_configure_failure("appimage-arguments-without-generator" "valid" "AppImage is never a default"
                                       "export_cpack(GENERATORS TGZ APPIMAGE_DESKTOP_FILE proof.desktop APPIMAGE_ICON_FILE proof-app.svg)")
_tip_expect_appimage_configure_failure("appimage-additional-generator-bypass" "valid" "not ADDITIONAL_CPACK_VARS CPACK_GENERATOR"
                                       "export_cpack(NO_DEFAULT_GENERATORS ADDITIONAL_CPACK_VARS CPACK_GENERATOR AppImage)")

_tip_write_appimage_fixture("valid" "valid" "${_tip_valid_export_call}")
_tip_proof_run_step(
  NAME
  "valid-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_fixture_source_dir}"
  -B
  "${_tip_fixture_build_dir}"
  ${_tip_toolchain_args})
SET(_tip_valid_cpack_config "${_tip_fixture_build_dir}/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_valid_cpack_config}" "CPACK_GENERATOR \"AppImage\"")
_tip_proof_assert_file_contains("${_tip_valid_cpack_config}" "CPACK_APPIMAGE_DESKTOP_FILE \"proof.desktop\"")
_tip_proof_assert_file_contains("${_tip_valid_cpack_config}" "CPACK_PACKAGE_ICON \"proof-app.svg\"")
_tip_proof_assert_file_contains("${_tip_valid_cpack_config}" "CPACK_APPIMAGE_TOOL_EXECUTABLE \"${_tip_fixture_source_dir}/fake-bin/appimagetool\"")
_tip_proof_assert_file_contains("${_tip_valid_cpack_config}" "CPACK_APPIMAGE_PATCHELF_EXECUTABLE \"${_tip_fixture_source_dir}/fake-bin/patchelf\"")

STRING(REGEX REPLACE "\\)$" " ADDITIONAL_CPACK_VARS CPACK_PACKAGE_DESCRIPTION APPIMAGE_ICON_FILE CPACK_PACKAGE_VENDOR KeywordValueVendor)" _tip_keyword_value_export_call "${_tip_valid_export_call}")
_tip_write_appimage_fixture("additional-keyword-value" "valid" "${_tip_keyword_value_export_call}")
_tip_proof_run_step(
  NAME
  "additional-keyword-value-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_fixture_source_dir}"
  -B
  "${_tip_fixture_build_dir}"
  ${_tip_toolchain_args})
_tip_proof_assert_file_contains("${_tip_fixture_build_dir}/CPackConfig.cmake" "CPACK_PACKAGE_DESCRIPTION \"APPIMAGE_ICON_FILE\"")
_tip_proof_assert_file_contains("${_tip_fixture_build_dir}/CPackConfig.cmake" "CPACK_PACKAGE_VENDOR \"KeywordValueVendor\"")

_tip_write_appimage_fixture("default-generators" "valid" "export_cpack(PACKAGE_NAME ProofDefaults)")
_tip_proof_run_step(
  NAME
  "default-generators-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_fixture_source_dir}"
  -B
  "${_tip_fixture_build_dir}"
  ${_tip_toolchain_args})
_tip_proof_assert_file_not_contains("${_tip_fixture_build_dir}/CPackConfig.cmake" "AppImage")

_tip_write_appimage_fixture("metadata-not-installed" "valid" "${_tip_valid_export_call}" OMIT_METADATA_INSTALL)
_tip_proof_run_step(
  NAME
  "metadata-not-installed-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_fixture_source_dir}"
  -B
  "${_tip_fixture_build_dir}"
  ${_tip_toolchain_args})
_tip_proof_expect_failure(
  NAME
  "metadata-not-installed-package"
  COMMAND
  "${CMAKE_CPACK_COMMAND}"
  -G
  AppImage
  --config
  "${_tip_fixture_build_dir}/CPackConfig.cmake"
  -B
  "${_tip_fixture_build_dir}/packages"
  EXPECT_CONTAINS
  "A desktop file is required")

MESSAGE(STATUS "[proof] CPack AppImage validation proof passed.")
