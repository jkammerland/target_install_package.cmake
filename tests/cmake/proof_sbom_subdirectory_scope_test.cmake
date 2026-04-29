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
  _tip_proof_fail("proof_sbom_subdirectory_scope requires CMake 4.3 or newer and should not be registered on older CMake versions")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/sbom-subdirectory-scope")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_case_root}/fixture-build")
set(_tip_install_prefix "${_tip_case_root}/fixture-install")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/default-sub/src")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/explicit-top-name/src")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/project-sub/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(TopProject VERSION 9.9.9 SPDX_LICENSE \"GPL-3.0-only\" DESCRIPTION \"Top-level SBOM metadata that must not leak\" HOMEPAGE_URL \"https://example.invalid/top-project-sbom\" LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "add_subdirectory(default-sub)\n"
  "add_subdirectory(explicit-top-name)\n"
  "add_subdirectory(project-sub)\n")

file(
  WRITE "${_tip_fixture_source_dir}/default-sub/CMakeLists.txt"
  "project(DefaultSubSbom VERSION 4.5.6 SPDX_LICENSE \"BSD-3-Clause\" DESCRIPTION \"Default subdirectory SBOM package\" HOMEPAGE_URL \"https://example.invalid/default-sub-sbom\" LANGUAGES CXX)\n"
  "set(CMAKE_EXPERIMENTAL_GENERATE_SBOM \"${TIP_SBOM_EXPERIMENTAL_VALUE}\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(default_sub_sbom STATIC src/default.cpp)\n"
  "target_install_package(default_sub_sbom EXPORT_NAME DefaultSubSbom SBOM SBOM_DESTINATION \"share/sbom/defaultsub\")\n")
file(WRITE "${_tip_fixture_source_dir}/default-sub/src/default.cpp" "int default_sub_sbom_value() { return 4; }\n")

file(
  WRITE "${_tip_fixture_source_dir}/explicit-top-name/CMakeLists.txt"
  "project(ExplicitTopNameSub VERSION 7.8.9 SPDX_LICENSE \"0BSD\" "
  "DESCRIPTION \"Explicit subdirectory metadata that should not be inherited\" HOMEPAGE_URL \"https://example.invalid/explicit-top-name-sub\" LANGUAGES CXX)\n"
  "set(CMAKE_EXPERIMENTAL_GENERATE_SBOM \"${TIP_SBOM_EXPERIMENTAL_VALUE}\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(explicit_top_sbom STATIC src/explicit.cpp)\n"
  "target_install_package(explicit_top_sbom EXPORT_NAME TopProject SBOM SBOM_NAME TopProject SBOM_DESTINATION \"share/sbom/explicittop\")\n")
file(WRITE "${_tip_fixture_source_dir}/explicit-top-name/src/explicit.cpp" "int explicit_top_sbom_value() { return 7; }\n")

file(
  WRITE "${_tip_fixture_source_dir}/project-sub/CMakeLists.txt"
  "project(ProjectSubSbom VERSION 5.6.7 SPDX_LICENSE \"Apache-2.0\" "
  "DESCRIPTION \"Explicit project subdirectory SBOM package\" HOMEPAGE_URL \"https://example.invalid/project-sub-sbom\" LANGUAGES CXX)\n"
  "set(CMAKE_EXPERIMENTAL_GENERATE_SBOM \"${TIP_SBOM_EXPERIMENTAL_VALUE}\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(project_sub_sbom STATIC src/project.cpp)\n"
  "target_install_package(project_sub_sbom EXPORT_NAME ProjectSubSbomExport SBOM SBOM_NAME ProjectNamedSbom SBOM_PROJECT ProjectSubSbom SBOM_DESTINATION \"share/sbom/projectsub\")\n")
file(WRITE "${_tip_fixture_source_dir}/project-sub/src/project.cpp" "int project_sub_sbom_value() { return 5; }\n")

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

set(_tip_default_sbom "${_tip_install_prefix}/share/sbom/defaultsub/DefaultSubSbom.spdx.json")
_tip_proof_find_spdx_document("${_tip_default_sbom}" "DefaultSubSbom" _tip_default_document_index)
_tip_proof_assert_json_path_string("${_tip_default_sbom}" "BSD-3-Clause" "@graph" ${_tip_default_document_index} "dataLicense")
_tip_proof_assert_json_path_string("${_tip_default_sbom}" "Default subdirectory SBOM package" "@graph" ${_tip_default_document_index} "description")
_tip_proof_assert_root_element_names("${_tip_default_sbom}" "${_tip_default_document_index}" "default_sub_sbom")
_tip_proof_assert_root_element("${_tip_default_sbom}" "${_tip_default_document_index}" "default_sub_sbom" "4.5.6" "https://example.invalid/default-sub-sbom")

set(_tip_explicit_top_sbom "${_tip_install_prefix}/share/sbom/explicittop/TopProject.spdx.json")
_tip_proof_find_spdx_document("${_tip_explicit_top_sbom}" "TopProject" _tip_explicit_top_document_index)
_tip_proof_assert_root_element_names("${_tip_explicit_top_sbom}" "${_tip_explicit_top_document_index}" "explicit_top_sbom")
_tip_proof_assert_root_element_json_path_string("${_tip_explicit_top_sbom}" "${_tip_explicit_top_document_index}" "explicit_top_sbom" "7.8.9" "software_packageVersion")
_tip_proof_assert_root_element_json_path_absent("${_tip_explicit_top_sbom}" "${_tip_explicit_top_document_index}" "explicit_top_sbom" "software_homePage")
_tip_proof_assert_file_not_contains("${_tip_explicit_top_sbom}" "GPL-3.0-only")
_tip_proof_assert_file_not_contains("${_tip_explicit_top_sbom}" "Top-level SBOM metadata that must not leak")
_tip_proof_assert_file_not_contains("${_tip_explicit_top_sbom}" "https://example.invalid/top-project-sbom")
_tip_proof_assert_file_not_contains("${_tip_explicit_top_sbom}" "0BSD")
_tip_proof_assert_file_not_contains("${_tip_explicit_top_sbom}" "Explicit subdirectory metadata that should not be inherited")
_tip_proof_assert_file_not_contains("${_tip_explicit_top_sbom}" "https://example.invalid/explicit-top-name-sub")

set(_tip_project_sbom "${_tip_install_prefix}/share/sbom/projectsub/ProjectNamedSbom.spdx.json")
_tip_proof_find_spdx_document("${_tip_project_sbom}" "ProjectNamedSbom" _tip_project_document_index)
_tip_proof_assert_json_path_string("${_tip_project_sbom}" "Apache-2.0" "@graph" ${_tip_project_document_index} "dataLicense")
_tip_proof_assert_json_path_string("${_tip_project_sbom}" "Explicit project subdirectory SBOM package" "@graph" ${_tip_project_document_index} "description")
_tip_proof_assert_root_element_names("${_tip_project_sbom}" "${_tip_project_document_index}" "project_sub_sbom")
_tip_proof_assert_root_element("${_tip_project_sbom}" "${_tip_project_document_index}" "project_sub_sbom" "5.6.7" "https://example.invalid/project-sub-sbom")

message(STATUS "[proof] SBOM subdirectory scope proof passed.")
