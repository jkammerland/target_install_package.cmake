cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-repeated-arguments")
set(_tip_source_dir "${_tip_case_root}/source")
set(_tip_build_dir "${_tip_case_root}/build")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}")
_tip_proof_append_toolchain_args(_tip_toolchain_args)
set(ENV{GPG_SIGNING_KEY} "")

# Composed argument blocks must retain every multi-value occurrence in encounter order.
set(_tip_fixture
    [=[
cmake_minimum_required(VERSION 3.25)
project(RepeatedArguments VERSION 1.2.3 LANGUAGES NONE)
include("@TIP_REPO_ROOT@/export_cpack.cmake")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/foo.txt" "Foo payload\n")
file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/bar.txt" "Bar payload\n")
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/foo.txt" DESTINATION share/repeated COMPONENT Foo)
install(FILES "${CMAKE_CURRENT_BINARY_DIR}/bar.txt" DESTINATION share/repeated COMPONENT Bar)
export_cpack(
  GENERATORS TGZ COMPONENTS Foo DEFAULT_COMPONENTS Foo CHECKSUMS SHA256
  GENERATORS ZIP COMPONENTS Bar DEFAULT_COMPONENTS Bar CHECKSUMS SHA512
  PACKAGE_VENDOR FirstVendor PACKAGE_VENDOR FinalVendor CHECKSUMS)
]=])
string(CONFIGURE "${_tip_fixture}" _tip_fixture @ONLY)
file(WRITE "${_tip_source_dir}/CMakeLists.txt" "${_tip_fixture}")
_tip_proof_run_step(
  NAME
  repeated-configure
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_source_dir}"
  -B
  "${_tip_build_dir}"
  ${_tip_toolchain_args})
include("${_tip_build_dir}/CPackConfig.cmake")
if(NOT CPACK_GENERATOR STREQUAL "TGZ;ZIP" OR NOT CPACK_COMPONENTS_ALL STREQUAL "Foo;Bar")
  _tip_proof_fail("Repeated GENERATORS and COMPONENTS must accumulate: '${CPACK_GENERATOR}', '${CPACK_COMPONENTS_ALL}'")
endif()
if(NOT CPACK_COMPONENT_FOO_DISABLED STREQUAL "FALSE" OR NOT CPACK_COMPONENT_BAR_DISABLED STREQUAL "FALSE")
  _tip_proof_fail("Repeated DEFAULT_COMPONENTS must select both components")
endif()
if(NOT CPACK_PACKAGE_VENDOR STREQUAL "FinalVendor")
  _tip_proof_fail("Repeated scalar arguments must retain the final value")
endif()

# Package without overriding generators, then verify both payloads in both formats.
_tip_proof_run_step(
  NAME
  repeated-package
  COMMAND
  "${CMAKE_CPACK_COMMAND}"
  --config
  "${_tip_build_dir}/CPackConfig.cmake"
  -B
  "${_tip_build_dir}/packages")
foreach(_tip_suffix tar.gz zip)
  file(GLOB _tip_archives "${_tip_build_dir}/packages/*.${_tip_suffix}")
  list(LENGTH _tip_archives _tip_archive_count)
  if(NOT _tip_archive_count EQUAL 2)
    _tip_proof_fail("Expected two component ${_tip_suffix} archives, got '${_tip_archives}'")
  endif()
  foreach(_tip_component Foo Bar)
    file(GLOB _tip_component_archives "${_tip_build_dir}/packages/*-${_tip_component}.${_tip_suffix}")
    list(LENGTH _tip_component_archives _tip_component_archive_count)
    if(NOT _tip_component_archive_count EQUAL 1)
      _tip_proof_fail("Expected one ${_tip_component} ${_tip_suffix} archive, got '${_tip_component_archives}'")
    endif()
    list(GET _tip_component_archives 0 _tip_archive)
    set(_tip_extract_dir "${_tip_build_dir}/extracted/${_tip_suffix}/${_tip_component}")
    file(ARCHIVE_EXTRACT INPUT "${_tip_archive}" DESTINATION "${_tip_extract_dir}")
    string(TOLOWER "${_tip_component}" _tip_payload_name)
    file(GLOB_RECURSE _tip_payloads "${_tip_extract_dir}/*${_tip_payload_name}.txt")
    list(LENGTH _tip_payloads _tip_payload_count)
    if(NOT _tip_payload_count EQUAL 1)
      _tip_proof_fail("Expected the ${_tip_component} payload in ${_tip_archive}, got '${_tip_payloads}'")
    endif()
    list(GET _tip_payloads 0 _tip_payload)
    file(READ "${_tip_payload}" _tip_contents)
    if(NOT _tip_contents STREQUAL "${_tip_component} payload\n")
      _tip_proof_fail("Incorrect ${_tip_component} payload in ${_tip_archive}")
    endif()

    foreach(_tip_algorithm SHA256 SHA512)
      string(TOLOWER "${_tip_algorithm}" _tip_extension)
      file(${_tip_algorithm} "${_tip_archive}" _tip_expected_hash)
      _tip_proof_assert_file_contains("${_tip_archive}.${_tip_extension}" "${_tip_expected_hash}")
    endforeach()
  endforeach()
endforeach()
message(STATUS "[proof] CPack repeated argument proof passed.")
