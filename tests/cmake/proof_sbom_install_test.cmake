cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()
if(NOT DEFINED TIP_SBOM_EXPERIMENTAL_VALUE OR TIP_SBOM_EXPERIMENTAL_VALUE STREQUAL "")
  _tip_proof_fail("TIP_SBOM_EXPERIMENTAL_VALUE is required")
endif()
if(CMAKE_VERSION VERSION_LESS "4.3")
  _tip_proof_fail("proof_sbom_install requires CMake 4.3 or newer and should not be registered on older CMake versions")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/sbom-install")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_case_root}/fixture-build")
set(_tip_install_prefix "${_tip_case_root}/fixture-install")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/include/proof_sbom")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_sbom_fixture VERSION 2.3.4 DESCRIPTION \"Proof SBOM package\" HOMEPAGE_URL \"https://example.invalid/proof-sbom\" LANGUAGES CXX)\n"
  "set(CMAKE_EXPERIMENTAL_GENERATE_SBOM \"${TIP_SBOM_EXPERIMENTAL_VALUE}\")\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(sbom_static STATIC src/static.cpp)\n"
  "set_target_properties(sbom_static PROPERTIES SPDX_LICENSE \"Apache-2.0\")\n"
  "target_compile_features(sbom_static PUBLIC cxx_std_17)\n"
  "target_sources(sbom_static PUBLIC FILE_SET HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"include/proof_sbom/static.hpp\")\n"
  "target_install_package(sbom_static EXPORT_NAME proof_sbom_pkg VERSION \${PROJECT_VERSION} "
  "SBOM SBOM_NAME ProofSbom SBOM_DESTINATION \"share/sbom/proofsbom\" SBOM_LICENSE \"MIT\" "
  "SBOM_DESCRIPTION \"Proof SBOM package\" SBOM_HOMEPAGE_URL "
  "\"https://example.invalid/proof-sbom\")\n"
  "add_library(sbom_shared SHARED src/shared.cpp)\n"
  "target_compile_features(sbom_shared PUBLIC cxx_std_17)\n"
  "target_sources(sbom_shared PUBLIC FILE_SET HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"include/proof_sbom/shared.hpp\")\n"
  "if(WIN32)\n"
  "  set_target_properties(sbom_shared PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)\n"
  "endif()\n"
  "target_install_package(sbom_shared EXPORT_NAME proof_sbom_pkg VERSION \${PROJECT_VERSION})\n"
  "add_library(sbom_iface INTERFACE)\n"
  "target_sources(sbom_iface INTERFACE FILE_SET HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"include/proof_sbom/iface.hpp\")\n"
  "target_install_package(sbom_iface EXPORT_NAME proof_sbom_pkg VERSION \${PROJECT_VERSION})\n")

file(WRITE "${_tip_fixture_source_dir}/include/proof_sbom/static.hpp" "int sbom_static_value();\n")
file(WRITE "${_tip_fixture_source_dir}/include/proof_sbom/shared.hpp" "int sbom_shared_value();\n")
file(WRITE "${_tip_fixture_source_dir}/include/proof_sbom/iface.hpp" "#pragma once\n")
file(WRITE "${_tip_fixture_source_dir}/src/static.cpp" "#include <proof_sbom/static.hpp>\nint sbom_static_value() { return 3; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/shared.cpp" "#include <proof_sbom/shared.hpp>\nint sbom_shared_value() { return 4; }\n")

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
  "fixture-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_fixture_build_dir}"
  --config
  Release
  --prefix
  "${_tip_install_prefix}")

file(GLOB _tip_sbom_files "${_tip_install_prefix}/share/sbom/proofsbom/*.spdx.json")
list(LENGTH _tip_sbom_files _tip_sbom_file_count)
if(NOT _tip_sbom_file_count EQUAL 1)
  _tip_proof_fail("Expected one installed SBOM file, got ${_tip_sbom_file_count}")
endif()
list(GET _tip_sbom_files 0 _tip_sbom_file)
_tip_proof_assert_exists("${_tip_sbom_file}")

_tip_proof_assert_json_path_string("${_tip_sbom_file}" "https://spdx.org/rdf/3.0.1/spdx-context.jsonld" "@context")
_tip_proof_find_spdx_document("${_tip_sbom_file}" "ProofSbom" _tip_document_index)
_tip_proof_assert_json_path_string("${_tip_sbom_file}" "MIT" "@graph" ${_tip_document_index} "dataLicense")
_tip_proof_assert_json_path_string("${_tip_sbom_file}" "Proof SBOM package" "@graph" ${_tip_document_index} "description")
_tip_proof_assert_root_element("${_tip_sbom_file}" "${_tip_document_index}" "sbom_static" "2.3.4" "https://example.invalid/proof-sbom")
_tip_proof_assert_root_element("${_tip_sbom_file}" "${_tip_document_index}" "sbom_shared" "2.3.4" "https://example.invalid/proof-sbom")
_tip_proof_assert_root_element("${_tip_sbom_file}" "${_tip_document_index}" "sbom_iface" "2.3.4" "https://example.invalid/proof-sbom")

message(STATUS "[proof] SBOM install proof passed.")
