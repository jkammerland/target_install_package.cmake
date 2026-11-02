cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-argument-contract")
file(REMOVE_RECURSE "${_tip_case_root}")
_tip_proof_append_toolchain_args(_tip_toolchain_args)

function(_tip_invalid_export name export_call expected)
  set(_tip_source_dir "${_tip_case_root}/${name}-src")
  set(_tip_build_dir "${_tip_case_root}/${name}-build")
  file(MAKE_DIRECTORY "${_tip_source_dir}")
  file(WRITE "${_tip_source_dir}/CMakeLists.txt" "cmake_minimum_required(VERSION 3.25)\nproject(ArgumentContract VERSION 1.2.3 LANGUAGES NONE)\n"
                                                 "include(\"${TIP_REPO_ROOT}/export_cpack.cmake\")\n${export_call}\n")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_tip_source_dir}" -B "${_tip_build_dir}" ${_tip_toolchain_args}
    RESULT_VARIABLE _tip_result
    OUTPUT_VARIABLE _tip_stdout
    ERROR_VARIABLE _tip_stderr)
  if(_tip_result EQUAL 0)
    _tip_proof_fail("${name}: invalid argument configuration unexpectedly succeeded")
  endif()
  # CMake wraps diagnostics to its output width; whitespace is not part of this contract.
  string(REGEX REPLACE "[ \r\n\t]+" " " _tip_diagnostic "${_tip_stdout}\n${_tip_stderr}")
  string(FIND "${_tip_diagnostic}" "${expected}" _tip_match)
  if(_tip_match EQUAL -1)
    _tip_proof_fail("${name}: expected '${expected}', got: ${_tip_diagnostic}")
  endif()
endfunction()

# Cover scalar, list, pair, and optional-boolean categories with representative errors.
_tip_invalid_export(scalar-at-end "export_cpack(PACKAGE_NAME)" "PACKAGE_NAME requires a value")
_tip_invalid_export(scalar-before-keyword "export_cpack(PACKAGE_CONTACT GENERATORS TGZ)" "PACKAGE_CONTACT requires a value")
_tip_invalid_export(empty-generator "export_cpack(GENERATORS \"\")" "GENERATORS requires a value")
_tip_invalid_export(empty-format "export_cpack(ARCHIVE_FORMAT \"\")" "ARCHIVE_FORMAT requires a non-empty value")
_tip_invalid_export(missing-components "export_cpack(COMPONENTS GENERATORS TGZ)" "COMPONENTS requires a value")
_tip_invalid_export(missing-default-components "export_cpack(DEFAULT_COMPONENTS)" "DEFAULT_COMPONENTS requires a value")
_tip_invalid_export(missing-container-components "export_cpack(CONTAINER_COMPONENTS)" "CONTAINER_COMPONENTS requires a value")
_tip_invalid_export(missing-additional-pair "export_cpack(ADDITIONAL_CPACK_VARS)" "must contain key/value pairs, got no arguments")
_tip_invalid_export(odd-additional-pair "export_cpack(ADDITIONAL_CPACK_VARS CPACK_PACKAGE_VENDOR)" "odd number of arguments")
_tip_invalid_export(invalid-boolean "export_cpack(GENERATE_CHECKSUMS maybe)" "must be ON or OFF")
_tip_invalid_export(archive-generator-conflict "export_cpack(ARCHIVE_FORMAT ZIP GENERATORS TGZ)" "ARCHIVE_FORMAT and GENERATORS cannot be used together")
_tip_invalid_export(invalid-archive "export_cpack(ARCHIVE_FORMAT RPM)" "must name a CPack archive generator")
_tip_invalid_export(duplicate-call "export_cpack()\nexport_cpack()" "can only be called once")

# Isolate package-tool lookup from the host PATH so this check also runs where RPM is installed.
set(_tip_source_dir "${_tip_case_root}/missing-rpmbuild-src")
set(_tip_build_dir "${_tip_case_root}/missing-rpmbuild-build")
file(MAKE_DIRECTORY "${_tip_source_dir}/empty-root")
set(_tip_fixture
    [=[
cmake_minimum_required(VERSION 3.25)
project(NativePrerequisite VERSION 1.2.3 LANGUAGES NONE)
include("@TIP_REPO_ROOT@/export_cpack.cmake")
set(CMAKE_FIND_ROOT_PATH "${CMAKE_CURRENT_SOURCE_DIR}/empty-root")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM ONLY)
export_cpack(GENERATORS RPM)
]=])
string(CONFIGURE "${_tip_fixture}" _tip_fixture @ONLY)
file(WRITE "${_tip_source_dir}/CMakeLists.txt" "${_tip_fixture}")
execute_process(
  COMMAND "${CMAKE_COMMAND}" -S "${_tip_source_dir}" -B "${_tip_build_dir}" ${_tip_toolchain_args}
  RESULT_VARIABLE _tip_result
  OUTPUT_VARIABLE _tip_stdout
  ERROR_VARIABLE _tip_stderr)
if(NOT _tip_result EQUAL 0)
  _tip_proof_fail("Missing native packaging tools must still permit metadata configuration: ${_tip_stdout}\n${_tip_stderr}")
endif()
string(FIND "${_tip_stdout}\n${_tip_stderr}" "requires 'rpmbuild'" _tip_warning)
if(_tip_warning EQUAL -1)
  _tip_proof_fail("Missing RPM packaging tool must produce a clear prerequisite warning: ${_tip_stdout}\n${_tip_stderr}")
endif()
include("${_tip_build_dir}/CPackConfig.cmake")
if(NOT CPACK_GENERATOR STREQUAL "RPM")
  _tip_proof_fail("Explicit native generator selection must remain authoritative")
endif()

message(STATUS "[proof] CPack argument contract proof passed.")
