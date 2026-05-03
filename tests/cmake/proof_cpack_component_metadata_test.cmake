cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/cpack-component-metadata")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_case_root}/fixture-build")
set(_tip_install_prefix "${_tip_case_root}/fixture-install")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_cpack_component_metadata VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "export_cpack(PACKAGE_NAME ProofCpackComponents PACKAGE_VERSION 1.0.0 GENERATORS TGZ NO_DEFAULT_GENERATORS)\n"
  "add_library(proof_core STATIC src/core.cpp)\n"
  "target_compile_features(proof_core PUBLIC cxx_std_17)\n"
  "add_library(proof_storage STATIC src/storage.cpp)\n"
  "target_link_libraries(proof_storage PUBLIC proof_core)\n"
  "target_compile_features(proof_storage PUBLIC cxx_std_17)\n"
  "target_install_package(proof_core EXPORT_NAME proof_cpack_component_pkg NAMESPACE Proof:: COMPONENT Core INCLUDE_ON_FIND_PACKAGE cmake/proof-extra.cmake)\n"
  "target_install_package(proof_storage EXPORT_NAME proof_cpack_component_pkg NAMESPACE Proof:: COMPONENT Storage)\n")

file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/cmake")
file(WRITE "${_tip_fixture_source_dir}/src/core.cpp" "int proof_core_value() { return 41; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/storage.cpp" "int proof_core_value(); int proof_storage_value() { return proof_core_value() + 1; }\n")
file(WRITE "${_tip_fixture_source_dir}/cmake/proof-extra.cmake" "set(proof_cpack_component_pkg_EXTRA_INCLUDED TRUE)\n")

set(_tip_fixture_configure_command "${CMAKE_COMMAND}" -S "${_tip_fixture_source_dir}" -B "${_tip_fixture_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})

_tip_proof_run_step(NAME "fixture-configure" COMMAND ${_tip_fixture_configure_command})
_tip_proof_run_step(
  NAME
  "fixture-build"
  COMMAND
  "${CMAKE_COMMAND}"
  --build
  "${_tip_fixture_build_dir}"
  --config
  Release)
_tip_proof_run_step(
  NAME
  "fixture-install-development"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_fixture_build_dir}"
  --config
  Release
  --prefix
  "${_tip_install_prefix}"
  --component
  Development)

set(_tip_config_file "${_tip_install_prefix}/share/cmake/proof_cpack_component_pkg/proof_cpack_component_pkgConfig.cmake")
set(_tip_extra_file "${_tip_install_prefix}/share/cmake/proof_cpack_component_pkg/proof-extra.cmake")
_tip_proof_assert_exists("${_tip_config_file}")
_tip_proof_assert_exists("${_tip_extra_file}")
_tip_proof_assert_file_contains("${_tip_config_file}" "proof-extra.cmake")

file(GLOB _tip_core_libraries "${_tip_install_prefix}/lib*/*proof_core*")
if(NOT _tip_core_libraries)
  _tip_proof_fail("Expected the unified Development component to install proof_core development artifacts")
endif()

file(GLOB _tip_storage_libraries "${_tip_install_prefix}/lib*/*proof_storage*")
if(NOT _tip_storage_libraries)
  _tip_proof_fail("Expected the unified Development component to install proof_storage development artifacts")
endif()

set(_tip_cpack_config_file "${_tip_fixture_build_dir}/CPackConfig.cmake")
_tip_proof_assert_exists("${_tip_cpack_config_file}")
file(READ "${_tip_cpack_config_file}" _tip_cpack_config_content)

foreach(_tip_expected_component IN ITEMS Core Storage Development)
  string(FIND "${_tip_cpack_config_content}" "${_tip_expected_component}" _tip_component_index)
  if(_tip_component_index EQUAL -1)
    _tip_proof_fail("Expected CPackConfig.cmake to contain auto-detected component '${_tip_expected_component}'")
  endif()
endforeach()

foreach(_tip_unexpected_component IN ITEMS Core_Development Storage_Development)
  string(FIND "${_tip_cpack_config_content}" "${_tip_unexpected_component}" _tip_component_index)
  if(NOT _tip_component_index EQUAL -1)
    _tip_proof_fail("Did not expect CPackConfig.cmake to contain legacy split SDK component '${_tip_unexpected_component}'")
  endif()
endforeach()

string(REGEX MATCH "set\\(CPACK_COMPONENT_DEVELOPMENT_DEPENDS \"([^\"]*)\"\\)" _tip_development_dep_match "${_tip_cpack_config_content}")
if(NOT _tip_development_dep_match)
  _tip_proof_fail("Expected Development CPack dependency declaration")
endif()

set(_tip_development_dependencies "${CMAKE_MATCH_1}")
foreach(_tip_expected_dependency IN ITEMS Core Storage)
  if(NOT "${_tip_expected_dependency}" IN_LIST _tip_development_dependencies)
    _tip_proof_fail("Expected Development to depend on '${_tip_expected_dependency}', got: ${_tip_development_dependencies}")
  endif()
endforeach()

message(STATUS "[proof] CPack component metadata proof passed.")
