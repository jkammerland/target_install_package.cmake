cmake_minimum_required(VERSION 4.4)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/source-file-sets")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_case_root}/fixture-build")
set(_tip_install_prefix "${_tip_case_root}/fixture-install")
set(_tip_consumer_source_dir "${_tip_case_root}/consumer-src")
set(_tip_consumer_build_dir "${_tip_case_root}/consumer-build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/include/proof" "${_tip_fixture_source_dir}/src" "${_tip_fixture_source_dir}/custom")

file(WRITE "${_tip_fixture_source_dir}/include/proof/source.hpp" "#pragma once\nint source_value();\nint generated_value();\n")
file(WRITE "${_tip_fixture_source_dir}/src/source.cpp" "#include <proof/source.hpp>\nint source_value() { return 40; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/generated.cpp.in" "#include <proof/source.hpp>\nint generated_value() { return @GENERATED_VALUE@; }\n")
file(WRITE "${_tip_fixture_source_dir}/custom/custom.cpp" "int custom_source_value() { return 7; }\n")

file(
  WRITE "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.4)\n"
  "project(proof_source_file_sets VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(source_only INTERFACE)\n"
  "target_sources(source_only INTERFACE FILE_SET api TYPE HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/include/proof/source.hpp\")\n"
  "target_sources(source_only INTERFACE FILE_SET implementation TYPE SOURCES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/src/source.cpp\")\n"
  "set(GENERATED_VALUE 2)\n"
  "target_configure_sources(source_only INTERFACE TYPE SOURCES FILE_SET generated_implementation OUTPUT_DIR \"\${CMAKE_CURRENT_BINARY_DIR}/generated\" BASE_DIRS \"\${CMAKE_CURRENT_BINARY_DIR}/generated\" FILES src/generated.cpp.in)\n"
  "target_install_package(source_only EXPORT_NAME proof_source_pkg NAMESPACE proof:: VERSION 1.0.0 SOURCE_FILE_SET_PROPERTIES implementation SKIP_LINTING ON implementation SKIP_PRECOMPILE_HEADERS ON generated_implementation SKIP_UNITY_BUILD_INCLUSION ON generated_implementation CXX_SCAN_FOR_MODULES OFF)\n"
  "add_library(custom_source_only INTERFACE)\n"
  "target_sources(custom_source_only INTERFACE FILE_SET implementation TYPE SOURCES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/custom\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/custom/custom.cpp\")\n"
  "target_install_package(custom_source_only EXPORT_NAME custom_source_pkg SOURCE_DESTINATION share/custom-source VERSION 1.0.0)\n")

_tip_proof_append_toolchain_args(_tip_toolchain_args)
_tip_proof_run_step(
  NAME
  "fixture-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_fixture_source_dir}"
  -B
  "${_tip_fixture_build_dir}"
  ${_tip_toolchain_args})
_tip_proof_run_step(
  NAME
  "fixture-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_fixture_build_dir}"
  --prefix
  "${_tip_install_prefix}")

_tip_proof_assert_exists("${_tip_install_prefix}/share/proof_source_pkg/src/source.cpp")
_tip_proof_assert_exists("${_tip_install_prefix}/share/proof_source_pkg/src/generated.cpp")
_tip_proof_assert_exists("${_tip_install_prefix}/share/custom-source/custom.cpp")
_tip_proof_assert_exists("${_tip_install_prefix}/include/proof/source.hpp")

file(REMOVE_RECURSE "${_tip_fixture_source_dir}" "${_tip_fixture_build_dir}")
file(MAKE_DIRECTORY "${_tip_consumer_source_dir}")
file(
  WRITE "${_tip_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.4)\n"
  "project(proof_source_consumer LANGUAGES CXX)\n"
  "find_package(proof_source_pkg 1.0 CONFIG REQUIRED PATHS \"${_tip_install_prefix}\" NO_DEFAULT_PATH)\n"
  "get_target_property(source_sets proof::source_only INTERFACE_SOURCE_SETS)\n"
  "foreach(expected implementation generated_implementation)\n"
  "  if(NOT expected IN_LIST source_sets)\n"
  "    message(FATAL_ERROR \"Missing installed source set: \${expected}; got: \${source_sets}\")\n"
  "  endif()\n"
  "  get_target_property(source_files proof::source_only SOURCE_SET_\${expected})\n"
  "  foreach(source_file IN LISTS source_files)\n"
  "    string(FIND \"\${source_file}\" \"${_tip_install_prefix}/\" prefix_index)\n"
  "    if(NOT prefix_index EQUAL 0)\n"
  "      message(FATAL_ERROR \"Source set path escaped the relocated prefix: \${source_file}\")\n"
  "    endif()\n"
  "  endforeach()\n"
  "endforeach()\n"
  "get_property(skip_lint FILE_SET implementation TARGET proof::source_only PROPERTY SKIP_LINTING)\n"
  "get_property(skip_pch FILE_SET implementation TARGET proof::source_only PROPERTY SKIP_PRECOMPILE_HEADERS)\n"
  "get_property(skip_unity FILE_SET generated_implementation TARGET proof::source_only PROPERTY SKIP_UNITY_BUILD_INCLUSION)\n"
  "get_property(scan_modules FILE_SET generated_implementation TARGET proof::source_only PROPERTY CXX_SCAN_FOR_MODULES)\n"
  "if(NOT skip_lint OR NOT skip_pch OR NOT skip_unity OR NOT scan_modules STREQUAL \"OFF\")\n"
  "  message(FATAL_ERROR \"Imported source file-set hygiene properties were not preserved\")\n"
  "endif()\n"
  "add_executable(proof_source_consumer main.cpp)\n"
  "target_link_libraries(proof_source_consumer PRIVATE proof::source_only)\n")
file(WRITE "${_tip_consumer_source_dir}/main.cpp" "#include <proof/source.hpp>\nint main() { return source_value() + generated_value() == 42 ? 0 : 1; }\n")

_tip_proof_run_step(
  NAME
  "consumer-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_consumer_source_dir}"
  -B
  "${_tip_consumer_build_dir}"
  ${_tip_toolchain_args})
_tip_proof_run_step(NAME "consumer-build" COMMAND "${CMAKE_COMMAND}" --build "${_tip_consumer_build_dir}")
_tip_proof_run_step(NAME "consumer-run" COMMAND "${_tip_consumer_build_dir}/proof_source_consumer${CMAKE_EXECUTABLE_SUFFIX}")

if(DEFINED TIP_OLD_CMAKE_COMMAND AND NOT "${TIP_OLD_CMAKE_COMMAND}" STREQUAL "")
  set(_tip_old_consumer_source_dir "${_tip_case_root}/old-consumer-src")
  set(_tip_old_consumer_build_dir "${_tip_case_root}/old-consumer-build")
  file(MAKE_DIRECTORY "${_tip_old_consumer_source_dir}")
  file(WRITE "${_tip_old_consumer_source_dir}/CMakeLists.txt" "cmake_minimum_required(VERSION 3.25)\n" "project(proof_source_old_consumer LANGUAGES NONE)\n"
                                                              "find_package(proof_source_pkg CONFIG REQUIRED PATHS \"${_tip_install_prefix}\" NO_DEFAULT_PATH)\n")
  _tip_proof_expect_failure(
    NAME
    "old-consumer-version-guard"
    COMMAND
    "${TIP_OLD_CMAKE_COMMAND}"
    -S
    "${_tip_old_consumer_source_dir}"
    -B
    "${_tip_old_consumer_build_dir}"
    EXPECT_CONTAINS
    "Package 'proof_source_pkg' contains SOURCES file sets")
endif()

message(STATUS "[proof] CMake 4.4 source file set proof passed.")
