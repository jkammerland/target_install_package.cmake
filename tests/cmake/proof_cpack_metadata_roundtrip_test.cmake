cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-metadata-roundtrip")
set(_tip_source_dir "${_tip_case_root}/source with spaces")
set(_tip_build_dir "${_tip_case_root}/build with spaces")
file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_source_dir}/package")
_tip_proof_append_toolchain_args(_tip_toolchain_args)

# Bracket arguments keep the fixture and its independent expectations literal.
set(_tip_fixture
    [==[
cmake_minimum_required(VERSION 3.25)
project(MetadataRoot VERSION 9.9.9 LANGUAGES NONE)
add_subdirectory(package)
]==])
file(WRITE "${_tip_source_dir}/CMakeLists.txt" "${_tip_fixture}")
set(_tip_fixture
    [==[
project(MetadataPackage VERSION 1.2.3 LANGUAGES NONE)
include("@TIP_REPO_ROOT@/export_cpack.cmake")
function(configure_package)
  set(description [=[Semicolons; "quotes", spaces, ${literal}, and C:\windows\path\]=])
  export_cpack(
    GENERATORS "TGZ;ZIP"
    PACKAGE_DESCRIPTION "${description}"
    PACKAGE_VENDOR [=[Vendor; "quoted" \slashes\]=]
    PACKAGE_CONTACT ""
    PACKAGE_HOMEPAGE_URL ""
    CHECKSUMS
    ADDITIONAL_CPACK_VARS
      CPACK_TEST_TEXT [=[Additional; "quotes" and C:\path with spaces\]=]
      CPACK_TEST_LIST "alpha;beta;gamma"
      CPACK_TEST_ESCAPED [=[a\;b;tail\]=]
      CPACK_TEST_BRACKETS [=[unmatched [ bracket]=]
      CPACK_TEST_EMPTY ""
      CPACK_TEST_KEYWORD PACKAGE_DESCRIPTION)
endfunction()
configure_package()
set(description "must not be captured at deferred execution")
]==])
string(CONFIGURE "${_tip_fixture}" _tip_fixture @ONLY)
file(WRITE "${_tip_source_dir}/package/CMakeLists.txt" "${_tip_fixture}")
_tip_proof_run_step(
  NAME
  metadata-configure
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_source_dir}"
  -B
  "${_tip_build_dir}"
  ${_tip_toolchain_args})

# Evaluate the serialized CMake programs; string matching would miss broken escaping.
foreach(_tip_config CPackConfig.cmake CPackSourceConfig.cmake)
  include("${_tip_build_dir}/${_tip_config}")
  if(NOT CPACK_PACKAGE_NAME STREQUAL "MetadataPackage" OR NOT CPACK_PACKAGE_VERSION STREQUAL "1.2.3")
    _tip_proof_fail("${_tip_config}: lost call-site project metadata")
  endif()
  if(NOT CPACK_PACKAGE_DESCRIPTION_SUMMARY STREQUAL [=[Semicolons; "quotes", spaces, ${literal}, and C:\windows\path\]=])
    _tip_proof_fail("${_tip_config}: description did not round-trip exactly: '${CPACK_PACKAGE_DESCRIPTION_SUMMARY}'")
  endif()
  if(NOT CPACK_PACKAGE_VENDOR STREQUAL [=[Vendor; "quoted" \slashes\]=])
    _tip_proof_fail("${_tip_config}: vendor did not round-trip exactly")
  endif()
  if(NOT CPACK_PACKAGE_CONTACT STREQUAL "" OR NOT CPACK_PACKAGE_HOMEPAGE_URL STREQUAL "")
    _tip_proof_fail("${_tip_config}: intentional empty metadata was replaced by defaults")
  endif()
  if(NOT CPACK_TEST_TEXT STREQUAL [=[Additional; "quotes" and C:\path with spaces\]=]
     OR NOT CPACK_TEST_LIST STREQUAL "alpha;beta;gamma"
     OR NOT CPACK_TEST_ESCAPED STREQUAL [=[a\;b;tail\]=]
     OR NOT CPACK_TEST_BRACKETS STREQUAL [=[unmatched [ bracket]=]
     OR NOT DEFINED CPACK_TEST_EMPTY
     OR NOT CPACK_TEST_EMPTY STREQUAL ""
     OR NOT CPACK_TEST_KEYWORD STREQUAL "PACKAGE_DESCRIPTION")
    _tip_proof_fail("${_tip_config}: additional CPack variables did not round-trip exactly")
  endif()
  if(NOT CPACK_VERBATIM_VARIABLES)
    _tip_proof_fail("${_tip_config}: CPack variable escaping must be enabled")
  endif()
endforeach()

include("${_tip_build_dir}/CPackConfig.cmake")
if(NOT CPACK_GENERATOR STREQUAL "TGZ;ZIP")
  _tip_proof_fail("Quoted semicolon-separated generator lists must remain lists")
endif()
message(STATUS "[proof] CPack metadata round-trip proof passed.")
