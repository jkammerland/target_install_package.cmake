cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/strict-validation")
set(_tip_collision_source_dir "${_tip_case_root}/configure-source-collision-src")
set(_tip_collision_build_dir "${_tip_case_root}/configure-source-collision-build")
set(_tip_cross_call_collision_source_dir "${_tip_case_root}/configure-source-cross-call-collision-src")
set(_tip_cross_call_collision_build_dir "${_tip_case_root}/configure-source-cross-call-collision-build")
set(_tip_equivalent_output_collision_source_dir "${_tip_case_root}/configure-source-equivalent-output-collision-src")
set(_tip_equivalent_output_collision_build_dir "${_tip_case_root}/configure-source-equivalent-output-collision-build")
set(_tip_trailing_output_collision_source_dir "${_tip_case_root}/configure-source-trailing-output-collision-src")
set(_tip_trailing_output_collision_build_dir "${_tip_case_root}/configure-source-trailing-output-collision-build")
set(_tip_same_source_cross_call_source_dir "${_tip_case_root}/configure-source-same-source-cross-call-src")
set(_tip_same_source_cross_call_build_dir "${_tip_case_root}/configure-source-same-source-cross-call-build")
set(_tip_notfound_source_cross_call_source_dir "${_tip_case_root}/configure-source-notfound-source-cross-call-src")
set(_tip_notfound_source_cross_call_build_dir "${_tip_case_root}/configure-source-notfound-source-cross-call-build")
set(_tip_notfound_output_source_dir "${_tip_case_root}/configure-source-notfound-output-src")
set(_tip_notfound_output_build_dir "${_tip_case_root}/configure-source-notfound-output-build")
set(_tip_relative_output_source_dir "${_tip_case_root}/configure-source-relative-output-src")
set(_tip_relative_output_build_dir "${_tip_case_root}/configure-source-relative-output-build")
set(_tip_duplicate_source_source_dir "${_tip_case_root}/configure-source-duplicate-source-src")
set(_tip_duplicate_source_build_dir "${_tip_case_root}/configure-source-duplicate-source-build")
set(_tip_missing_template_source_dir "${_tip_case_root}/missing-template-src")
set(_tip_missing_template_build_dir "${_tip_case_root}/missing-template-build")
set(_tip_missing_additional_source_dir "${_tip_case_root}/missing-additional-src")
set(_tip_missing_additional_build_dir "${_tip_case_root}/missing-additional-build")
set(_tip_component_only_source_dir "${_tip_case_root}/component-only-src")
set(_tip_component_only_build_dir "${_tip_case_root}/component-only-build")
set(_tip_late_target_source_dir "${_tip_case_root}/late-target-src")
set(_tip_late_target_build_dir "${_tip_case_root}/late-target-build")
set(_tip_odd_cpack_source_dir "${_tip_case_root}/odd-cpack-vars-src")
set(_tip_odd_cpack_build_dir "${_tip_case_root}/odd-cpack-vars-build")
set(_tip_empty_cpack_source_dir "${_tip_case_root}/empty-cpack-vars-src")
set(_tip_empty_cpack_build_dir "${_tip_case_root}/empty-cpack-vars-build")
set(_tip_list_cpack_source_dir "${_tip_case_root}/list-cpack-vars-src")
set(_tip_list_cpack_build_dir "${_tip_case_root}/list-cpack-vars-build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_collision_source_dir}/include/foo" "${_tip_collision_source_dir}/include/bar")
file(MAKE_DIRECTORY "${_tip_cross_call_collision_source_dir}/include/foo" "${_tip_cross_call_collision_source_dir}/include/bar")
file(MAKE_DIRECTORY "${_tip_equivalent_output_collision_source_dir}/include/foo" "${_tip_equivalent_output_collision_source_dir}/include/bar")
file(MAKE_DIRECTORY "${_tip_trailing_output_collision_source_dir}/include/foo" "${_tip_trailing_output_collision_source_dir}/include/bar")
file(MAKE_DIRECTORY "${_tip_same_source_cross_call_source_dir}/include/proof")
file(MAKE_DIRECTORY "${_tip_notfound_source_cross_call_source_dir}/include/proof")
file(MAKE_DIRECTORY "${_tip_notfound_output_source_dir}/include/proof" "${_tip_notfound_output_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_relative_output_source_dir}/a/include/proof" "${_tip_relative_output_source_dir}/b/include/proof")
file(MAKE_DIRECTORY "${_tip_duplicate_source_source_dir}/include/proof")
file(MAKE_DIRECTORY "${_tip_missing_template_source_dir}/include")
file(MAKE_DIRECTORY "${_tip_missing_additional_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_component_only_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_late_target_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_odd_cpack_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_empty_cpack_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_list_cpack_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_collision_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_configure_source_collision LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
  "add_library(proof_collision INTERFACE)\n"
  "target_configure_sources(proof_collision INTERFACE OUTPUT_DIR \"\${CMAKE_CURRENT_BINARY_DIR}/generated\" FILES include/foo/config.h.in include/bar/config.h.in)\n")
file(WRITE "${_tip_collision_source_dir}/include/foo/config.h.in" "#define PROOF_COLLISION 1\n")
file(WRITE "${_tip_collision_source_dir}/include/bar/config.h.in" "#define PROOF_COLLISION 2\n")

set(_tip_collision_configure_command "${CMAKE_COMMAND}" -S "${_tip_collision_source_dir}" -B "${_tip_collision_build_dir}" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "configured-source-output-collision" COMMAND ${_tip_collision_configure_command} EXPECT_CONTAINS "Multiple template files")

file(
  WRITE "${_tip_cross_call_collision_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_configure_source_cross_call_collision LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
  "add_library(proof_cross_call_collision INTERFACE)\n"
  "target_configure_sources(proof_cross_call_collision INTERFACE OUTPUT_DIR \"\${CMAKE_CURRENT_BINARY_DIR}/generated\" FILES include/foo/config.h.in)\n"
  "target_configure_sources(proof_cross_call_collision INTERFACE OUTPUT_DIR \"\${CMAKE_CURRENT_BINARY_DIR}/generated\" FILES include/bar/config.h.in)\n")
file(WRITE "${_tip_cross_call_collision_source_dir}/include/foo/config.h.in" "#define PROOF_CROSS_CALL_COLLISION 1\n")
file(WRITE "${_tip_cross_call_collision_source_dir}/include/bar/config.h.in" "#define PROOF_CROSS_CALL_COLLISION 2\n")

set(_tip_cross_call_collision_configure_command "${CMAKE_COMMAND}" -S "${_tip_cross_call_collision_source_dir}" -B "${_tip_cross_call_collision_build_dir}" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "configured-source-output-cross-call-collision" COMMAND ${_tip_cross_call_collision_configure_command} EXPECT_CONTAINS "Multiple template files")

file(
  WRITE "${_tip_equivalent_output_collision_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_configure_source_equivalent_output_collision LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
  "add_library(proof_equivalent_output_collision INTERFACE)\n"
  "target_configure_sources(proof_equivalent_output_collision INTERFACE OUTPUT_DIR generated FILES include/foo/config.h.in)\n"
  "target_configure_sources(proof_equivalent_output_collision INTERFACE OUTPUT_DIR \"\${CMAKE_CURRENT_BINARY_DIR}/generated\" FILES include/bar/config.h.in)\n")
file(WRITE "${_tip_equivalent_output_collision_source_dir}/include/foo/config.h.in" "#define PROOF_EQUIVALENT_OUTPUT_COLLISION 1\n")
file(WRITE "${_tip_equivalent_output_collision_source_dir}/include/bar/config.h.in" "#define PROOF_EQUIVALENT_OUTPUT_COLLISION 2\n")

set(_tip_equivalent_output_collision_configure_command "${CMAKE_COMMAND}" -S "${_tip_equivalent_output_collision_source_dir}" -B "${_tip_equivalent_output_collision_build_dir}" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "configured-source-equivalent-output-collision" COMMAND ${_tip_equivalent_output_collision_configure_command} EXPECT_CONTAINS "Multiple template files")

file(
  WRITE "${_tip_trailing_output_collision_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_configure_source_trailing_output_collision LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
  "add_library(proof_trailing_output_collision INTERFACE)\n"
  "target_configure_sources(proof_trailing_output_collision INTERFACE OUTPUT_DIR \"\${CMAKE_CURRENT_BINARY_DIR}/generated\" FILES include/foo/config.h.in)\n"
  "target_configure_sources(proof_trailing_output_collision INTERFACE OUTPUT_DIR \"\${CMAKE_CURRENT_BINARY_DIR}/generated/\" FILES include/bar/config.h.in)\n")
file(WRITE "${_tip_trailing_output_collision_source_dir}/include/foo/config.h.in" "#define PROOF_TRAILING_OUTPUT_COLLISION 1\n")
file(WRITE "${_tip_trailing_output_collision_source_dir}/include/bar/config.h.in" "#define PROOF_TRAILING_OUTPUT_COLLISION 2\n")

set(_tip_trailing_output_collision_configure_command "${CMAKE_COMMAND}" -S "${_tip_trailing_output_collision_source_dir}" -B "${_tip_trailing_output_collision_build_dir}" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "configured-source-trailing-output-collision" COMMAND ${_tip_trailing_output_collision_configure_command} EXPECT_CONTAINS "Multiple template files")

file(
  WRITE "${_tip_same_source_cross_call_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_configure_source_same_source_cross_call LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
  "add_library(proof_same_source_first INTERFACE)\n"
  "add_library(proof_same_source_second INTERFACE)\n"
  "set(PROOF_VALUE 1)\n"
  "target_configure_sources(proof_same_source_first INTERFACE OUTPUT_DIR generated FILES include/proof/config.h.in)\n"
  "set(PROOF_VALUE 2)\n"
  "target_configure_sources(proof_same_source_second INTERFACE OUTPUT_DIR generated FILES include/proof/config.h.in)\n")
file(WRITE "${_tip_same_source_cross_call_source_dir}/include/proof/config.h.in" "#define PROOF_VALUE @PROOF_VALUE@\n")

set(_tip_same_source_cross_call_configure_command "${CMAKE_COMMAND}" -S "${_tip_same_source_cross_call_source_dir}" -B "${_tip_same_source_cross_call_build_dir}" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "configured-source-same-source-cross-call" COMMAND ${_tip_same_source_cross_call_configure_command} EXPECT_CONTAINS "Multiple template files")

file(
  WRITE "${_tip_notfound_source_cross_call_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_configure_source_notfound_source_cross_call LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
  "add_library(proof_notfound_source_first INTERFACE)\n"
  "add_library(proof_notfound_source_second INTERFACE)\n"
  "set(PROOF_VALUE 1)\n"
  "target_configure_sources(proof_notfound_source_first INTERFACE OUTPUT_DIR generated FILES include/proof/config-NOTFOUND)\n"
  "set(PROOF_VALUE 2)\n"
  "target_configure_sources(proof_notfound_source_second INTERFACE OUTPUT_DIR generated FILES include/proof/config-NOTFOUND)\n")
file(WRITE "${_tip_notfound_source_cross_call_source_dir}/include/proof/config-NOTFOUND" "#define PROOF_VALUE @PROOF_VALUE@\n")

set(_tip_notfound_source_cross_call_configure_command "${CMAKE_COMMAND}" -S "${_tip_notfound_source_cross_call_source_dir}" -B "${_tip_notfound_source_cross_call_build_dir}" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "configured-source-notfound-source-cross-call" COMMAND ${_tip_notfound_source_cross_call_configure_command} EXPECT_CONTAINS "Multiple template files")

file(
  WRITE "${_tip_notfound_output_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_configure_source_notfound_output LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
  "add_executable(proof_notfound_output src/main.cpp)\n"
  "set(PROOF_VALUE 7)\n"
  "target_configure_sources(proof_notfound_output PRIVATE OUTPUT_DIR generated FILES include/proof/config-NOTFOUND.in)\n")
file(WRITE "${_tip_notfound_output_source_dir}/include/proof/config-NOTFOUND.in" "#define PROOF_NOTFOUND_VALUE @PROOF_VALUE@\n")
file(
  WRITE "${_tip_notfound_output_source_dir}/src/main.cpp"
  "#include \"config-NOTFOUND\"\n"
  "int main() { return PROOF_NOTFOUND_VALUE == 7 ? 0 : 1; }\n")

set(_tip_notfound_output_configure_command "${CMAKE_COMMAND}" -S "${_tip_notfound_output_source_dir}" -B "${_tip_notfound_output_build_dir}" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "configured-source-notfound-output-configure" COMMAND ${_tip_notfound_output_configure_command})
_tip_proof_assert_exists("${_tip_notfound_output_build_dir}/generated/config-NOTFOUND")
_tip_proof_run_step(NAME "configured-source-notfound-output-build" COMMAND "${CMAKE_COMMAND}" --build "${_tip_notfound_output_build_dir}")

file(
  WRITE "${_tip_relative_output_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_configure_source_relative_output LANGUAGES CXX)\n"
  "add_subdirectory(a)\n"
  "add_subdirectory(b)\n")
foreach(_tip_relative_subdir IN ITEMS a b)
  file(
    WRITE "${_tip_relative_output_source_dir}/${_tip_relative_subdir}/CMakeLists.txt"
    "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
    "add_library(proof_relative_${_tip_relative_subdir} INTERFACE)\n"
    "target_configure_sources(proof_relative_${_tip_relative_subdir} INTERFACE OUTPUT_DIR generated FILES include/proof/config.h.in)\n")
  file(WRITE "${_tip_relative_output_source_dir}/${_tip_relative_subdir}/include/proof/config.h.in" "#define PROOF_RELATIVE_${_tip_relative_subdir} 1\n")
endforeach()

set(_tip_relative_output_configure_command "${CMAKE_COMMAND}" -S "${_tip_relative_output_source_dir}" -B "${_tip_relative_output_build_dir}" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "configured-source-relative-output-subdirs" COMMAND ${_tip_relative_output_configure_command})
_tip_proof_assert_exists("${_tip_relative_output_build_dir}/a/generated/config.h")
_tip_proof_assert_exists("${_tip_relative_output_build_dir}/b/generated/config.h")

file(
  WRITE "${_tip_duplicate_source_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_configure_source_duplicate_source LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
  "add_library(proof_duplicate_source INTERFACE)\n"
  "target_configure_sources(proof_duplicate_source INTERFACE FILES include/proof/config.h.in include/proof/../proof/config.h.in)\n")
file(WRITE "${_tip_duplicate_source_source_dir}/include/proof/config.h.in" "#define PROOF_DUPLICATE_SOURCE 1\n")

set(_tip_duplicate_source_configure_command "${CMAKE_COMMAND}" -S "${_tip_duplicate_source_source_dir}" -B "${_tip_duplicate_source_build_dir}" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "configured-source-normalized-duplicate-source" COMMAND ${_tip_duplicate_source_configure_command})
_tip_proof_assert_exists("${_tip_duplicate_source_build_dir}/configured/proof_duplicate_source/config.h")

file(
  WRITE "${_tip_missing_template_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_missing_template LANGUAGES CXX)\n"
  "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
  "add_library(proof_missing_template INTERFACE)\n"
  "target_configure_sources(proof_missing_template INTERFACE FILES include/missing.h.in)\n")

set(_tip_missing_template_configure_command "${CMAKE_COMMAND}" -S "${_tip_missing_template_source_dir}" -B "${_tip_missing_template_build_dir}" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "missing-configured-source-template" COMMAND ${_tip_missing_template_configure_command} EXPECT_CONTAINS "Template file not found")

file(
  WRITE "${_tip_missing_additional_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_missing_additional VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_missing_additional STATIC src/proof.cpp)\n"
  "target_install_package(proof_missing_additional ADDITIONAL_FILES NOTICE.txt)\n")
file(WRITE "${_tip_missing_additional_source_dir}/src/proof.cpp" "int proof_missing_additional_value() { return 0; }\n")

set(_tip_missing_additional_configure_command "${CMAKE_COMMAND}" -S "${_tip_missing_additional_source_dir}" -B "${_tip_missing_additional_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "missing-additional-file" COMMAND ${_tip_missing_additional_configure_command} EXPECT_CONTAINS "Additional file to install")

file(
  WRITE "${_tip_component_only_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_component_only VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_component_only STATIC src/proof.cpp)\n"
  "target_install_package(proof_component_only ADDITIONAL_FILES_COMPONENTS OptionalDocs)\n")
file(WRITE "${_tip_component_only_source_dir}/src/proof.cpp" "int proof_component_only_value() { return 0; }\n")

set(_tip_component_only_configure_command "${CMAKE_COMMAND}" -S "${_tip_component_only_source_dir}" -B "${_tip_component_only_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "additional-files-component-only" COMMAND ${_tip_component_only_configure_command} EXPECT_CONTAINS "ADDITIONAL_FILES_COMPONENTS requires")

file(
  WRITE "${_tip_late_target_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_late_target VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_late_first STATIC src/first.cpp)\n"
  "add_library(proof_late_second STATIC src/second.cpp)\n"
  "target_install_package(proof_late_first EXPORT_NAME proof_late_pkg)\n"
  "finalize_package(EXPORT_NAME proof_late_pkg)\n"
  "target_install_package(proof_late_second EXPORT_NAME proof_late_pkg)\n")
file(WRITE "${_tip_late_target_source_dir}/src/first.cpp" "int proof_late_first_value() { return 1; }\n")
file(WRITE "${_tip_late_target_source_dir}/src/second.cpp" "int proof_late_second_value() { return 2; }\n")

set(_tip_late_target_configure_command "${CMAKE_COMMAND}" -S "${_tip_late_target_source_dir}" -B "${_tip_late_target_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "late-target-after-finalize" COMMAND ${_tip_late_target_configure_command} EXPECT_CONTAINS "Export 'proof_late_pkg'")

file(
  WRITE "${_tip_odd_cpack_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_odd_cpack_vars VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_odd_cpack_vars STATIC src/proof.cpp)\n"
  "target_install_package(proof_odd_cpack_vars)\n"
  "export_cpack(PACKAGE_NAME ProofOddCpack GENERATORS TGZ NO_DEFAULT_GENERATORS ADDITIONAL_CPACK_VARS CPACK_PACKAGE_VENDOR)\n")
file(WRITE "${_tip_odd_cpack_source_dir}/src/proof.cpp" "int proof_odd_cpack_value() { return 0; }\n")

set(_tip_odd_cpack_configure_command "${CMAKE_COMMAND}" -S "${_tip_odd_cpack_source_dir}" -B "${_tip_odd_cpack_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "odd-additional-cpack-vars" COMMAND ${_tip_odd_cpack_configure_command} EXPECT_CONTAINS "key/value pairs" "odd number")

file(
  WRITE "${_tip_empty_cpack_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_empty_cpack_vars VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_empty_cpack_vars STATIC src/proof.cpp)\n"
  "target_install_package(proof_empty_cpack_vars)\n"
  "export_cpack(PACKAGE_NAME ProofEmptyCpack GENERATORS TGZ NO_DEFAULT_GENERATORS ADDITIONAL_CPACK_VARS)\n")
file(WRITE "${_tip_empty_cpack_source_dir}/src/proof.cpp" "int proof_empty_cpack_value() { return 0; }\n")

set(_tip_empty_cpack_configure_command "${CMAKE_COMMAND}" -S "${_tip_empty_cpack_source_dir}" -B "${_tip_empty_cpack_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_expect_failure(NAME "empty-additional-cpack-vars" COMMAND ${_tip_empty_cpack_configure_command} EXPECT_CONTAINS "key/value pairs" "no arguments")

file(
  WRITE "${_tip_list_cpack_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_list_cpack_vars VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_list_cpack_vars STATIC src/proof.cpp)\n"
  "target_install_package(proof_list_cpack_vars)\n"
  "export_cpack(PACKAGE_NAME ProofListCpack GENERATORS TGZ NO_DEFAULT_GENERATORS ADDITIONAL_CPACK_VARS CPACK_SOURCE_IGNORE_FILES \"foo;bar\")\n")
file(WRITE "${_tip_list_cpack_source_dir}/src/proof.cpp" "int proof_list_cpack_value() { return 0; }\n")

set(_tip_list_cpack_configure_command "${CMAKE_COMMAND}" -S "${_tip_list_cpack_source_dir}" -B "${_tip_list_cpack_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})
_tip_proof_run_step(NAME "list-valued-additional-cpack-vars" COMMAND ${_tip_list_cpack_configure_command})
_tip_proof_assert_file_contains("${_tip_list_cpack_build_dir}/CPackConfig.cmake" "set(CPACK_SOURCE_IGNORE_FILES \"foo;bar\")")

message(STATUS "[proof] Strict validation proof passed.")
