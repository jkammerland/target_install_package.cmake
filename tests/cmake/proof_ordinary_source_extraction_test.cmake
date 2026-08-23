cmake_minimum_required(VERSION 4.4)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/ose")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_fixture_source_dir}/build")
set(_tip_install_prefix "${_tip_case_root}/fixture-install")
set(_tip_consumer_source_dir "${_tip_case_root}/consumer-src")
set(_tip_consumer_build_dir "${_tip_case_root}/consumer-build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/include/proof" "${_tip_fixture_source_dir}/src")
file(WRITE "${_tip_fixture_source_dir}/include/proof/ordinary.hpp" "#pragma once\nint ordinary_value();\nint generated_value();\n")
file(WRITE "${_tip_fixture_source_dir}/src/ordinary.cpp" "#include <proof/ordinary.hpp>\nint ordinary_value() { return 40; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/generated.cpp.in" "#include <proof/ordinary.hpp>\nint generated_value() { return 2; }\n")
file(
  WRITE "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.4)\n"
  "project(proof_ordinary_source_extraction VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_custom_command(OUTPUT \"\${CMAKE_CURRENT_BINARY_DIR}/generated.cpp\" COMMAND \"\${CMAKE_COMMAND}\" -E copy \"\${CMAKE_CURRENT_SOURCE_DIR}/src/generated.cpp.in\" \"\${CMAKE_CURRENT_BINARY_DIR}/generated.cpp\" DEPENDS \"\${CMAKE_CURRENT_SOURCE_DIR}/src/generated.cpp.in\")\n"
  "add_custom_target(generate_ordinary_source ALL DEPENDS \"\${CMAKE_CURRENT_BINARY_DIR}/generated.cpp\")\n"
  "add_library(ordinary_source_only INTERFACE)\n"
  "target_sources(ordinary_source_only INTERFACE FILE_SET headers TYPE HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/include/proof/ordinary.hpp\")\n"
  "target_sources(ordinary_source_only INTERFACE src/ordinary.cpp \"\${CMAKE_CURRENT_BINARY_DIR}/generated.cpp\")\n"
  "set_source_files_properties(\"\${CMAKE_CURRENT_BINARY_DIR}/generated.cpp\" PROPERTIES GENERATED TRUE)\n"
  "add_dependencies(ordinary_source_only generate_ordinary_source)\n"
  "target_install_package(ordinary_source_only EXPORT_NAME ordinary_source_pkg NAMESPACE ordinary:: VERSION 1.0.0 SOURCE_FILE_SET_FROM_TARGET_SOURCES implementation)\n")

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
_tip_proof_run_step(NAME "fixture-build" COMMAND "${CMAKE_COMMAND}" --build "${_tip_fixture_build_dir}")
_tip_proof_run_step(
  NAME
  "fixture-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_fixture_build_dir}"
  --prefix
  "${_tip_install_prefix}")

_tip_proof_assert_exists("${_tip_install_prefix}/share/ordinary_source_pkg/src/src/ordinary.cpp")
_tip_proof_assert_exists("${_tip_install_prefix}/share/ordinary_source_pkg/src/build/generated.cpp")

file(REMOVE_RECURSE "${_tip_fixture_source_dir}" "${_tip_fixture_build_dir}")
file(MAKE_DIRECTORY "${_tip_consumer_source_dir}")
file(
  WRITE "${_tip_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.4)\n"
  "project(proof_ordinary_source_consumer LANGUAGES CXX)\n"
  "find_package(ordinary_source_pkg 1.0 CONFIG REQUIRED PATHS \"${_tip_install_prefix}\" NO_DEFAULT_PATH)\n"
  "get_target_property(source_sets ordinary::ordinary_source_only INTERFACE_SOURCE_SETS)\n"
  "if(NOT \"implementation\" IN_LIST source_sets)\n"
  "  message(FATAL_ERROR \"Missing extracted source file set: \${source_sets}\")\n"
  "endif()\n"
  "get_target_property(source_files ordinary::ordinary_source_only SOURCE_SET_implementation)\n"
  "foreach(source_file IN LISTS source_files)\n"
  "  string(FIND \"\${source_file}\" \"${_tip_install_prefix}/\" prefix_index)\n"
  "  if(NOT prefix_index EQUAL 0)\n"
  "    message(FATAL_ERROR \"Extracted source escaped the relocated prefix: \${source_file}\")\n"
  "  endif()\n"
  "endforeach()\n"
  "add_executable(proof_ordinary_source_consumer main.cpp)\n"
  "target_link_libraries(proof_ordinary_source_consumer PRIVATE ordinary::ordinary_source_only)\n")
file(WRITE "${_tip_consumer_source_dir}/main.cpp" "#include <proof/ordinary.hpp>\nint main() { return ordinary_value() + generated_value() == 42 ? 0 : 1; }\n")

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
_tip_proof_run_step(NAME "consumer-run" COMMAND "${_tip_consumer_build_dir}/proof_ordinary_source_consumer${CMAKE_EXECUTABLE_SUFFIX}")

message(STATUS "[proof] Ordinary source extraction proof passed.")
