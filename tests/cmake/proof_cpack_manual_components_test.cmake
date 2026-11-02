cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-manual-components")
file(REMOVE_RECURSE "${_tip_case_root}")
_tip_proof_append_toolchain_args(_tip_toolchain_args)

function(_tip_manual_component_case name export_arguments expected_components expect_warning)
  set(_tip_source_dir "${_tip_case_root}/${name}-src")
  set(_tip_build_dir "${_tip_case_root}/${name}-build")
  file(MAKE_DIRECTORY "${_tip_source_dir}")
  set(_tip_fixture
      [=[
cmake_minimum_required(VERSION 3.25)
project(ManualComponents VERSION 1.2.3 LANGUAGES CXX)
set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)
include("@TIP_REPO_ROOT@/cmake/load_target_install_package.cmake")
export_cpack(GENERATORS TGZ @export_arguments@)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/core.cpp" "int core() { return 7; }\n")
add_library(core SHARED "${CMAKE_CURRENT_BINARY_DIR}/core.cpp")
set_target_properties(core PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)
target_install_package(core EXPORT_NAME ManualComponents)
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/manual.txt" "manual component payload\n")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/manual.txt" DESTINATION share/docs COMPONENT Documentation)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/manual.txt" DESTINATION share/unclassified)
]=])
  string(CONFIGURE "${_tip_fixture}" _tip_fixture @ONLY)
  file(WRITE "${_tip_source_dir}/CMakeLists.txt" "${_tip_fixture}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${_tip_source_dir}" -B "${_tip_build_dir}" ${_tip_toolchain_args}
    RESULT_VARIABLE _tip_result
    OUTPUT_VARIABLE _tip_stdout
    ERROR_VARIABLE _tip_stderr)
  if(NOT _tip_result EQUAL 0)
    _tip_proof_fail("${name}: configuration failed: ${_tip_stdout}\n${_tip_stderr}")
  endif()
  set(_tip_output "${_tip_stdout}\n${_tip_stderr}")
  string(FIND "${_tip_output}" "omits manual install components" _tip_warning)
  if(expect_warning)
    if(_tip_warning EQUAL -1
       OR NOT _tip_output MATCHES "Documentation"
       OR NOT _tip_output MATCHES "Unspecified")
      _tip_proof_fail("${name}: expected warning naming both omitted manual components: ${_tip_output}")
    endif()
  elseif(NOT _tip_warning EQUAL -1)
    _tip_proof_fail("${name}: explicit COMPONENTS must suppress the omission warning")
  endif()

  include("${_tip_build_dir}/CPackConfig.cmake")
  list(SORT CPACK_COMPONENTS_ALL)
  if(NOT CPACK_COMPONENTS_ALL STREQUAL expected_components)
    _tip_proof_fail("${name}: expected '${expected_components}', got '${CPACK_COMPONENTS_ALL}'")
  endif()
  _tip_proof_run_step(
    NAME
    "${name}-build"
    COMMAND
    "${CMAKE_COMMAND}"
    --build
    "${_tip_build_dir}"
    --config
    Release)
  _tip_proof_run_step(
    NAME
    "${name}-package"
    COMMAND
    "${CMAKE_CPACK_COMMAND}"
    -C
    Release
    --config
    "${_tip_build_dir}/CPackConfig.cmake"
    -B
    "${_tip_build_dir}/packages")
  file(GLOB _tip_archives "${_tip_build_dir}/packages/*.tar.gz")
  if(NOT _tip_archives)
    _tip_proof_fail("${name}: packaging produced no archives")
  endif()
  foreach(_tip_archive IN LISTS _tip_archives)
    file(ARCHIVE_EXTRACT INPUT "${_tip_archive}" DESTINATION "${_tip_build_dir}/extracted")
  endforeach()
  # DESTDIR archives can retain the install prefix; inspect payloads at any prefix.
  file(GLOB_RECURSE _tip_manual_payloads "${_tip_build_dir}/extracted/*manual.txt")
  if(name STREQUAL "explicit-manual")
    list(LENGTH _tip_manual_payloads _tip_manual_payload_count)
    if(NOT _tip_manual_payload_count EQUAL 1)
      _tip_proof_fail("${name}: expected only the Documentation payload, got '${_tip_manual_payloads}'")
    endif()
    list(GET _tip_manual_payloads 0 _tip_manual_payload)
    if(NOT _tip_manual_payload MATCHES "/share/docs/manual[.]txt$")
      _tip_proof_fail("${name}: packaged an unselected manual component: ${_tip_manual_payload}")
    endif()
    _tip_proof_assert_file_contains("${_tip_manual_payload}" "manual component payload")
  elseif(_tip_manual_payloads)
    _tip_proof_fail("${name}: registered component packages must exclude manual payloads: ${_tip_manual_payloads}")
  endif()
endfunction()

_tip_manual_component_case(automatic "" "Development;Runtime" TRUE)
_tip_manual_component_case(explicit-registered "COMPONENTS Runtime Development" "Development;Runtime" FALSE)
_tip_manual_component_case(explicit-manual "COMPONENTS Documentation" "Documentation" FALSE)
message(STATUS "[proof] CPack manual component warning and filtering proof passed.")
