CMAKE_MINIMUM_REQUIRED(VERSION 4.2)

INCLUDE("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

FOREACH(_tip_required_variable IN ITEMS TIP_REPO_ROOT TIP_PROOF_TEST_ROOT TIP_APPIMAGE_TOOL_EXECUTABLE TIP_APPIMAGE_PATCHELF_EXECUTABLE)
  IF(NOT DEFINED ${_tip_required_variable} OR "${${_tip_required_variable}}" STREQUAL "")
    _tip_proof_fail("${_tip_required_variable} is required")
  ENDIF()
ENDFOREACH()
IF(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
  _tip_proof_fail("The live AppImage proof requires a Linux host")
ENDIF()
IF(NOT CMAKE_CPACK_COMMAND)
  _tip_proof_fail("CMAKE_CPACK_COMMAND is required")
ENDIF()
_tip_proof_assert_exists("${TIP_APPIMAGE_TOOL_EXECUTABLE}")
_tip_proof_assert_exists("${TIP_APPIMAGE_PATCHELF_EXECUTABLE}")
IF(DEFINED TIP_APPIMAGE_RUNTIME_FILE AND NOT "${TIP_APPIMAGE_RUNTIME_FILE}" STREQUAL "")
  _tip_proof_assert_exists("${TIP_APPIMAGE_RUNTIME_FILE}")
ENDIF()

SET(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-appimage-real")
SET(_tip_source_dir "${TIP_REPO_ROOT}/examples/cpack-appimage")
SET(_tip_build_dir "${_tip_case_root}/build")
SET(_tip_preinstall_dir "${_tip_case_root}/preinstall")
SET(_tip_package_dir "${_tip_case_root}/packages")
SET(_tip_extract_dir "${_tip_case_root}/extract")
SET(_tip_package_basename "tip-appimage-example-1.2.3-x86_64")
SET(_tip_appimage "${_tip_package_dir}/${_tip_package_basename}.AppImage")
FILE(REMOVE_RECURSE "${_tip_case_root}")
FILE(MAKE_DIRECTORY "${_tip_package_dir}" "${_tip_extract_dir}")

_tip_proof_append_toolchain_args(_tip_toolchain_args)
SET(_tip_configure_command
    "${CMAKE_COMMAND}" -S "${_tip_source_dir}" -B "${_tip_build_dir}" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr "-DTIP_APPIMAGE_TOOL_EXECUTABLE=${TIP_APPIMAGE_TOOL_EXECUTABLE}"
    "-DTIP_APPIMAGE_PATCHELF_EXECUTABLE=${TIP_APPIMAGE_PATCHELF_EXECUTABLE}" "-DTIP_APPIMAGE_PACKAGE_FILE_NAME=${_tip_package_basename}" ${_tip_toolchain_args})
IF(DEFINED TIP_APPIMAGE_RUNTIME_FILE AND NOT "${TIP_APPIMAGE_RUNTIME_FILE}" STREQUAL "")
  LIST(APPEND _tip_configure_command "-DTIP_APPIMAGE_RUNTIME_FILE=${TIP_APPIMAGE_RUNTIME_FILE}")
ENDIF()

_tip_proof_run_step(NAME "configure" COMMAND ${_tip_configure_command})
_tip_proof_run_step(
  NAME
  "build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_build_dir}"
  --config
  Release)
_tip_proof_run_step(
  NAME
  "preinstall"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_build_dir}"
  --config
  Release
  --prefix
  "${_tip_preinstall_dir}")
EXECUTE_PROCESS(
  COMMAND "${TIP_APPIMAGE_PATCHELF_EXECUTABLE}" --print-rpath "${_tip_preinstall_dir}/bin/tip-appimage"
  RESULT_VARIABLE _tip_preinstall_rpath_result
  OUTPUT_VARIABLE _tip_preinstall_rpath
  ERROR_VARIABLE _tip_preinstall_rpath_error
  OUTPUT_STRIP_TRAILING_WHITESPACE)
IF(NOT _tip_preinstall_rpath_result EQUAL 0 OR NOT _tip_preinstall_rpath STREQUAL "")
  _tip_proof_fail("Expected an empty pre-package executable RPATH, got '${_tip_preinstall_rpath}': ${_tip_preinstall_rpath_error}")
ENDIF()
_tip_proof_run_step(
  NAME
  "package"
  COMMAND
  "${CMAKE_COMMAND}"
  -E
  env
  ARCH=x86_64
  SOURCE_DATE_EPOCH=1704067200
  "${CMAKE_CPACK_COMMAND}"
  -G
  AppImage
  -C
  Release
  --config
  "${_tip_build_dir}/CPackConfig.cmake"
  -B
  "${_tip_package_dir}")

FILE(GLOB _tip_appimages "${_tip_package_dir}/*.AppImage")
LIST(LENGTH _tip_appimages _tip_appimage_count)
IF(NOT _tip_appimage_count EQUAL 1)
  _tip_proof_fail("Expected exactly one monolithic AppImage, found ${_tip_appimage_count}: ${_tip_appimages}")
ENDIF()
_tip_proof_assert_exists("${_tip_appimage}")
FILE(
  READ "${_tip_appimage}" _tip_elf_magic
  OFFSET 0
  LIMIT 4
  HEX)
IF(NOT _tip_elf_magic STREQUAL "7f454c46")
  _tip_proof_fail("Expected ${_tip_appimage} to start with an ELF header, got ${_tip_elf_magic}")
ENDIF()

_tip_proof_run_step(
  NAME
  "extract"
  COMMAND
  "${CMAKE_COMMAND}"
  -E
  chdir
  "${_tip_extract_dir}"
  "${_tip_appimage}"
  --appimage-extract)
SET(_tip_appdir "${_tip_extract_dir}/squashfs-root")
FOREACH(_tip_expected_path IN ITEMS usr/bin/tip-appimage usr/lib/libtip_appimage_greeting.so usr/include/tip-appimage-sdk/greeting.hpp usr/share/doc/tip_appimage_example/runtime-dependencies.txt
                                    usr/share/applications/io.github.target_install_package.appimage.desktop usr/share/icons/hicolor/scalable/apps/tip-appimage.svg)
  _tip_proof_assert_exists("${_tip_appdir}/${_tip_expected_path}")
ENDFOREACH()
_tip_proof_assert_exists("${_tip_appdir}/AppRun")
_tip_proof_assert_exists("${_tip_appdir}/io.github.target_install_package.appimage.desktop")
_tip_proof_assert_exists("${_tip_appdir}/tip-appimage.svg")

FOREACH(_tip_elf IN ITEMS "${_tip_appdir}/usr/bin/tip-appimage")
  EXECUTE_PROCESS(
    COMMAND "${TIP_APPIMAGE_PATCHELF_EXECUTABLE}" --print-rpath "${_tip_elf}"
    RESULT_VARIABLE _tip_rpath_result
    OUTPUT_VARIABLE _tip_rpath
    ERROR_VARIABLE _tip_rpath_error
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  IF(NOT _tip_rpath_result EQUAL 0 OR NOT _tip_rpath STREQUAL "$ORIGIN/../lib")
    _tip_proof_fail("Expected AppImage RPATH '$ORIGIN/../lib' for ${_tip_elf}, got '${_tip_rpath}': ${_tip_rpath_error}")
  ENDIF()
ENDFOREACH()
EXECUTE_PROCESS(
  COMMAND "${TIP_APPIMAGE_PATCHELF_EXECUTABLE}" --print-rpath "${_tip_appdir}/usr/lib/libtip_appimage_greeting.so"
  RESULT_VARIABLE _tip_library_rpath_result
  OUTPUT_VARIABLE _tip_library_rpath
  ERROR_VARIABLE _tip_library_rpath_error
  OUTPUT_STRIP_TRAILING_WHITESPACE)
IF(NOT _tip_library_rpath_result EQUAL 0 OR NOT _tip_library_rpath STREQUAL "$ORIGIN")
  _tip_proof_fail("Expected preserved library RPATH '$ORIGIN', got '${_tip_library_rpath}': ${_tip_library_rpath_error}")
ENDIF()

EXECUTE_PROCESS(
  COMMAND "${_tip_appdir}/AppRun"
  RESULT_VARIABLE _tip_apprun_result
  OUTPUT_VARIABLE _tip_apprun_output
  ERROR_VARIABLE _tip_apprun_error
  OUTPUT_STRIP_TRAILING_WHITESPACE)
IF(NOT _tip_apprun_result EQUAL 0 OR NOT _tip_apprun_output STREQUAL "target_install_package AppImage example")
  _tip_proof_fail("Extracted AppRun failed (${_tip_apprun_result}): '${_tip_apprun_output}' '${_tip_apprun_error}'")
ENDIF()

EXECUTE_PROCESS(
  COMMAND "${CMAKE_COMMAND}" -E env APPIMAGE_EXTRACT_AND_RUN=1 "${_tip_appimage}"
  RESULT_VARIABLE _tip_appimage_result
  OUTPUT_VARIABLE _tip_appimage_output
  ERROR_VARIABLE _tip_appimage_error
  OUTPUT_STRIP_TRAILING_WHITESPACE)
IF(NOT _tip_appimage_result EQUAL 0 OR NOT _tip_appimage_output STREQUAL "target_install_package AppImage example")
  _tip_proof_fail("Generated AppImage failed (${_tip_appimage_result}): '${_tip_appimage_output}' '${_tip_appimage_error}'")
ENDIF()

MESSAGE(STATUS "[proof] Real CPack AppImage proof passed: ${_tip_appimage}")
