cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()
if(NOT CMAKE_VERSION VERSION_LESS "4.2")
  _tip_proof_fail("proof_cpack_appimage_old_cmake_guard requires CMake older than 4.2")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-appimage-old-cmake")
set(_tip_source_dir "${_tip_case_root}/src")
set(_tip_build_dir "${_tip_case_root}/build")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/fake-bin")
file(WRITE "${_tip_source_dir}/proof.desktop" "[Desktop Entry]\nType=Application\nName=Old CMake proof\nExec=proof-app\nIcon=proof-app\n")
file(WRITE "${_tip_source_dir}/proof-app.svg" "<svg xmlns=\"http://www.w3.org/2000/svg\"/>\n")
foreach(_tip_fake_tool IN ITEMS appimagetool patchelf)
  file(WRITE "${_tip_source_dir}/fake-bin/${_tip_fake_tool}" "#!/bin/sh\nexit 0\n")
endforeach()
file(
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
file(
  WRITE "${_tip_source_dir}/CMakeLists.txt"
  "CMAKE_MINIMUM_REQUIRED(VERSION 3.25)\n"
  "PROJECT(proof_cpack_appimage_old_cmake VERSION 1.0.0 LANGUAGES NONE)\n"
  "INCLUDE(\"${TIP_REPO_ROOT}/export_cpack.cmake\")\n"
  "INSTALL(FILES proof.desktop proof-app.svg DESTINATION share/proof)\n"
  "export_cpack(GENERATORS AppImage APPIMAGE_DESKTOP_FILE proof.desktop APPIMAGE_ICON_FILE proof-app.svg APPIMAGE_TOOL_EXECUTABLE fake-bin/appimagetool APPIMAGE_PATCHELF_EXECUTABLE fake-bin/patchelf)\n"
)

_tip_proof_append_toolchain_args(_tip_toolchain_args)
_tip_proof_expect_failure(
  NAME
  "old-cmake-appimage-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_source_dir}"
  -B
  "${_tip_build_dir}"
  ${_tip_toolchain_args}
  EXPECT_CONTAINS
  "requires CMake 4.2"
  "got CMake ${CMAKE_VERSION}")

message(STATUS "[proof] CPack AppImage old-CMake guard proof passed.")
