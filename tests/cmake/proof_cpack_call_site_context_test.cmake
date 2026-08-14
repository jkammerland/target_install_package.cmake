cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-call-site-context")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_case_root}")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

function(_tip_configure_cpack_fixture name)
  set(_tip_source_dir "${_tip_case_root}/${name}-src")
  set(_tip_build_dir "${_tip_case_root}/${name}-build")
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
endfunction()

set(_tip_auto_source_dir "${_tip_case_root}/auto-src")
file(MAKE_DIRECTORY "${_tip_auto_source_dir}/package")
file(WRITE "${_tip_auto_source_dir}/CMakeLists.txt"
     "cmake_minimum_required(VERSION 3.25)\n" "project(TopPackage VERSION 9.9.9 DESCRIPTION \"Top package description\" HOMEPAGE_URL \"https://top.invalid\" LANGUAGES NONE)\n"
     "add_subdirectory(package)\n")
file(WRITE "${_tip_auto_source_dir}/package/CMakeLists.txt"
     "project(CallSitePackage VERSION 1.2.3 DESCRIPTION \"Call-site package description\" HOMEPAGE_URL \"https://call-site.invalid\" LANGUAGES NONE)\n"
     "include(\"${TIP_REPO_ROOT}/export_cpack.cmake\")\n" "export_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS)\n")
file(WRITE "${_tip_auto_source_dir}/package/LICENSE" "Call-site license\n")

_tip_configure_cpack_fixture(auto)
set(_tip_auto_config "${_tip_case_root}/auto-build/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_auto_config}" "set(CPACK_PACKAGE_NAME \"CallSitePackage\")")
_tip_proof_assert_file_contains("${_tip_auto_config}" "set(CPACK_PACKAGE_VERSION \"1.2.3\")")
_tip_proof_assert_file_contains("${_tip_auto_config}" "set(CPACK_PACKAGE_DESCRIPTION_SUMMARY \"Call-site package description\")")
_tip_proof_assert_file_contains("${_tip_auto_config}" "set(CPACK_PACKAGE_HOMEPAGE_URL \"https://call-site.invalid\")")
_tip_proof_assert_file_contains("${_tip_auto_config}" "set(CPACK_RESOURCE_FILE_LICENSE \"${_tip_auto_source_dir}/package/LICENSE\")")

set(_tip_relative_source_dir "${_tip_case_root}/relative-src")
file(MAKE_DIRECTORY "${_tip_relative_source_dir}/package/legal")
file(WRITE "${_tip_relative_source_dir}/CMakeLists.txt" "cmake_minimum_required(VERSION 3.25)\n" "project(RelativeTop VERSION 8.8.8 LANGUAGES NONE)\n" "add_subdirectory(package)\n")
file(WRITE "${_tip_relative_source_dir}/package/CMakeLists.txt" "project(RelativeCallSite VERSION 2.3.4 LANGUAGES NONE)\n" "include(\"${TIP_REPO_ROOT}/export_cpack.cmake\")\n"
                                                                "export_cpack(LICENSE_FILE legal/COPYING.txt GENERATORS TGZ NO_DEFAULT_GENERATORS)\n")
file(WRITE "${_tip_relative_source_dir}/package/legal/COPYING.txt" "Relative license\n")

_tip_configure_cpack_fixture(relative)
set(_tip_relative_config "${_tip_case_root}/relative-build/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_relative_config}" "set(CPACK_RESOURCE_FILE_LICENSE \"${_tip_relative_source_dir}/package/legal/COPYING.txt\")")

set(_tip_no_version_source_dir "${_tip_case_root}/no-version-src")
file(MAKE_DIRECTORY "${_tip_no_version_source_dir}/package")
file(WRITE "${_tip_no_version_source_dir}/CMakeLists.txt" "cmake_minimum_required(VERSION 3.25)\n" "project(VersionedTop VERSION 7.7.7 LANGUAGES NONE)\n" "add_subdirectory(package)\n")
file(WRITE "${_tip_no_version_source_dir}/package/CMakeLists.txt" "project(UnversionedCallSite LANGUAGES NONE)\n" "include(\"${TIP_REPO_ROOT}/export_cpack.cmake\")\n"
                                                                  "export_cpack(GENERATORS TGZ NO_DEFAULT_GENERATORS)\n")

_tip_configure_cpack_fixture(no-version)
set(_tip_no_version_config "${_tip_case_root}/no-version-build/CPackConfig.cmake")
_tip_proof_assert_file_contains("${_tip_no_version_config}" "set(CPACK_PACKAGE_NAME \"UnversionedCallSite\")")
_tip_proof_assert_file_contains("${_tip_no_version_config}" "set(CPACK_PACKAGE_VERSION \"1.0.0\")")

message(STATUS "[proof] Deferred CPack call-site context proof passed.")
