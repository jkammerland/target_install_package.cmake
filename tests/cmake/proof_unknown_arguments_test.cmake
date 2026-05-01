cmake_minimum_required(VERSION 3.25)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/unknown-arguments")
set(_tip_tip_source_dir "${_tip_case_root}/target-install-package-src")
set(_tip_tip_build_dir "${_tip_case_root}/target-install-package-build")
set(_tip_cpack_source_dir "${_tip_case_root}/export-cpack-src")
set(_tip_cpack_build_dir "${_tip_case_root}/export-cpack-build")
set(_tip_configure_sources_source_dir "${_tip_case_root}/target-configure-sources-src")
set(_tip_configure_sources_build_dir "${_tip_case_root}/target-configure-sources-build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_tip_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_cpack_source_dir}/src")
file(MAKE_DIRECTORY "${_tip_configure_sources_source_dir}/src")

_tip_proof_append_toolchain_args(_tip_toolchain_args)

file(
  WRITE "${_tip_tip_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n" "project(proof_unknown_target_install_package VERSION 1.0.0 LANGUAGES CXX)\n" "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n" "add_library(proof_unknown_lib STATIC src/proof.cpp)\n"
  "target_install_package(proof_unknown_lib EXPORT_NAME proof_unknown_pkg BOGUS_ARGUMENT value)\n")
file(WRITE "${_tip_tip_source_dir}/src/proof.cpp" "int proof_unknown_value() { return 0; }\n")

set(_tip_tip_configure_command "${CMAKE_COMMAND}" -S "${_tip_tip_source_dir}" -B "${_tip_tip_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})

_tip_proof_expect_failure(NAME "target-install-package-unknown-argument" COMMAND ${_tip_tip_configure_command} EXPECT_CONTAINS "Unknown arguments")

file(
  WRITE "${_tip_cpack_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 3.25)\n"
  "project(proof_unknown_export_cpack VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(proof_unknown_cpack_lib STATIC src/proof.cpp)\n"
  "target_install_package(proof_unknown_cpack_lib)\n"
  "export_cpack(PACKAGE_NAME ProofUnknown BOGUS_CPACK_ARGUMENT value GENERATORS TGZ)\n")
file(WRITE "${_tip_cpack_source_dir}/src/proof.cpp" "int proof_unknown_cpack_value() { return 0; }\n")

set(_tip_cpack_configure_command "${CMAKE_COMMAND}" -S "${_tip_cpack_source_dir}" -B "${_tip_cpack_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})

_tip_proof_expect_failure(NAME "export-cpack-unknown-argument" COMMAND ${_tip_cpack_configure_command} EXPECT_CONTAINS "Unknown arguments")

file(WRITE "${_tip_configure_sources_source_dir}/CMakeLists.txt"
     "cmake_minimum_required(VERSION 3.25)\n" "project(proof_unknown_target_configure_sources VERSION 1.0.0 LANGUAGES CXX)\n" "include(\"${TIP_REPO_ROOT}/target_configure_sources.cmake\")\n"
     "add_executable(proof_unknown_configure_sources src/main.cpp)\n" "target_configure_sources(proof_unknown_configure_sources PRIVATE BOGUS_CONFIGURE_ARGUMENT value FILES src/config.h.in)\n")
file(WRITE "${_tip_configure_sources_source_dir}/src/main.cpp" "#include \"config.h\"\nint main() { return PROOF_VALUE; }\n")
file(WRITE "${_tip_configure_sources_source_dir}/src/config.h.in" "#define PROOF_VALUE 0\n")

set(_tip_configure_sources_configure_command "${CMAKE_COMMAND}" -S "${_tip_configure_sources_source_dir}" -B "${_tip_configure_sources_build_dir}" "-DCMAKE_BUILD_TYPE=Release" ${_tip_toolchain_args})

_tip_proof_expect_failure(NAME "target-configure-sources-unknown-argument" COMMAND ${_tip_configure_sources_configure_command} EXPECT_CONTAINS "Unknown arguments")

message(STATUS "[proof] Unknown argument proof passed.")
