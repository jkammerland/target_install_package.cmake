cmake_minimum_required(VERSION 4.4)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/csl")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_case_root}/fixture-build")
set(_tip_install_prefix "${_tip_case_root}/fixture-install")
set(_tip_consumer_source_dir "${_tip_case_root}/consumer-src")
set(_tip_consumer_build_dir "${_tip_case_root}/consumer-build")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/include/proof" "${_tip_fixture_source_dir}/src" "${_tip_fixture_source_dir}/private")
file(WRITE "${_tip_fixture_source_dir}/include/proof/source.hpp" "#pragma once\nint source_value();\n")
file(WRITE "${_tip_fixture_source_dir}/include/proof/modes.hpp" "#pragma once\nint shared_value();\nint object_value();\nint auto_value();\n")
file(WRITE "${_tip_fixture_source_dir}/private/private.hpp" "#pragma once\nint private_value();\n")
file(WRITE "${_tip_fixture_source_dir}/private/private.cpp" "#include <private.hpp>\nint private_value() { return 3; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/source.cpp"
     "#include <proof/source.hpp>\n#include <private.hpp>\nint generated_value();\nint source_value() { return PRIVATE_VALUE + private_value() + generated_value(); }\n")
file(WRITE "${_tip_fixture_source_dir}/src/generated.cpp.in" "int generated_value() { return @GENERATED_VALUE@; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/shared.cpp" "#include <proof/modes.hpp>\nint shared_value() { return 43; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/object.cpp" "#include <proof/modes.hpp>\nint object_value() { return 44; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/auto.cpp" "#include <proof/modes.hpp>\nint auto_value() { return 45; }\n")
file(
  WRITE "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.4)\n"
  "project(proof_consumer_local_source_libraries VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(private_support STATIC private/private.cpp)\n"
  "add_library(Build::support ALIAS private_support)\n"
  "target_include_directories(private_support PUBLIC \$<BUILD_INTERFACE:\${CMAKE_CURRENT_SOURCE_DIR}/private> \$<INSTALL_INTERFACE:include>)\n"
  "target_sources(private_support PUBLIC FILE_SET headers TYPE HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/private\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/private/private.hpp\")\n"
  "add_library(source_backed STATIC)\n"
  "target_sources(source_backed PUBLIC FILE_SET headers TYPE HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/include/proof/source.hpp\")\n"
  "target_sources(source_backed PUBLIC FILE_SET implementation TYPE SOURCES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/src/source.cpp\")\n"
  "set(GENERATED_VALUE 2)\n"
  "target_configure_sources(source_backed PUBLIC TYPE SOURCES FILE_SET generated_implementation OUTPUT_DIR \"\${CMAKE_CURRENT_BINARY_DIR}/generated\" BASE_DIRS \"\${CMAKE_CURRENT_BINARY_DIR}/generated\" FILES src/generated.cpp.in)\n"
  "target_compile_definitions(source_backed PRIVATE PRIVATE_VALUE=37 PUBLIC PUBLIC_VALUE=2)\n"
  "target_link_libraries(source_backed PRIVATE Build::support)\n"
  "target_install_package(source_backed EXPORT_NAME proof_consumer_source_pkg NAMESPACE proof:: VERSION 1.0.0 ADDITIONAL_TARGETS private_support SOURCE_LIBRARY_TYPE STATIC SOURCE_LIBRARY_ALIAS rebuilt_static SOURCE_FILE_SET_PROPERTIES implementation SKIP_LINTING ON)\n"
  "add_library(shared_source INTERFACE)\n"
  "target_sources(shared_source INTERFACE FILE_SET headers TYPE HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/include/proof/modes.hpp\")\n"
  "target_sources(shared_source INTERFACE FILE_SET implementation TYPE SOURCES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/src/shared.cpp\")\n"
  "target_install_package(shared_source EXPORT_NAME proof_consumer_source_pkg NAMESPACE proof:: VERSION 1.0.0 SOURCE_LIBRARY_TYPE SHARED SOURCE_LIBRARY_ALIAS rebuilt_shared)\n"
  "add_library(object_source INTERFACE)\n"
  "target_install_package(object_source EXPORT_NAME proof_consumer_source_pkg NAMESPACE proof:: VERSION 1.0.0 SOURCE_FILE_SET_FROM_TARGET_SOURCES implementation SOURCE_LIBRARY_TYPE OBJECT SOURCE_LIBRARY_ALIAS rebuilt_object)\n"
  "target_sources(object_source INTERFACE FILE_SET headers TYPE HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/include/proof/modes.hpp\")\n"
  "target_sources(object_source INTERFACE \"\${CMAKE_CURRENT_SOURCE_DIR}/src/object.cpp\")\n"
  "add_library(auto_source INTERFACE)\n"
  "target_sources(auto_source INTERFACE FILE_SET headers TYPE HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/include/proof/modes.hpp\")\n"
  "target_sources(auto_source INTERFACE FILE_SET implementation TYPE SOURCES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/src/auto.cpp\")\n"
  "target_install_package(auto_source EXPORT_NAME proof_consumer_source_pkg NAMESPACE proof:: VERSION 1.0.0 SOURCE_LIBRARY_TYPE AUTO SOURCE_LIBRARY_ALIAS rebuilt_auto)\n")

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

set(_tip_package_config "${_tip_install_prefix}/share/cmake/proof_consumer_source_pkg/proof_consumer_source_pkgConfig.cmake")
_tip_proof_assert_file_contains("${_tip_package_config}" "WINDOWS_EXPORT_ALL_SYMBOLS ON")
_tip_proof_assert_file_contains("${_tip_package_config}" "proof::private_support")
_tip_proof_assert_file_not_contains("${_tip_package_config}" "Build::support")

file(REMOVE_RECURSE "${_tip_fixture_source_dir}" "${_tip_fixture_build_dir}")
file(MAKE_DIRECTORY "${_tip_consumer_source_dir}")
file(
  WRITE "${_tip_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.4)\n"
  "project(proof_consumer_local_source_consumer LANGUAGES CXX)\n"
  "find_package(proof_consumer_source_pkg 1.0 CONFIG REQUIRED PATHS \"${_tip_install_prefix}\" NO_DEFAULT_PATH)\n"
  "foreach(expected rebuilt_static rebuilt_shared rebuilt_object rebuilt_auto)\n"
  "  if(NOT TARGET proof::\${expected})\n"
  "    message(FATAL_ERROR \"Missing consumer-local source alias: proof::\${expected}\")\n"
  "  endif()\n"
  "endforeach()\n"
  "get_target_property(static_type proof::rebuilt_static TYPE)\n"
  "get_target_property(shared_type proof::rebuilt_shared TYPE)\n"
  "get_target_property(object_type proof::rebuilt_object TYPE)\n"
  "get_target_property(auto_type proof::rebuilt_auto TYPE)\n"
  "if(NOT static_type STREQUAL \"STATIC_LIBRARY\" OR NOT shared_type STREQUAL \"SHARED_LIBRARY\" OR NOT object_type STREQUAL \"OBJECT_LIBRARY\" OR NOT auto_type STREQUAL \"SHARED_LIBRARY\")\n"
  "  message(FATAL_ERROR \"Unexpected consumer-local target types: \${static_type};\${shared_type};\${object_type};\${auto_type}\")\n"
  "endif()\n"
  "get_target_property(static_target proof::rebuilt_static ALIASED_TARGET)\n"
  "get_target_property(static_source_sets \${static_target} SOURCE_SETS)\n"
  "if(NOT implementation IN_LIST static_source_sets)\n"
  "  message(FATAL_ERROR \"Consumer-local static target did not preserve the implementation source set: \${static_source_sets}\")\n"
  "endif()\n"
  "get_property(static_skip_lint FILE_SET implementation TARGET \${static_target} PROPERTY SKIP_LINTING)\n"
  "if(NOT static_skip_lint)\n"
  "  message(FATAL_ERROR \"Consumer-local implementation source set did not preserve SKIP_LINTING\")\n"
  "endif()\n"
  "get_target_property(object_target proof::rebuilt_object ALIASED_TARGET)\n"
  "get_target_property(object_source_sets \${object_target} SOURCE_SETS)\n"
  "if(NOT implementation IN_LIST object_source_sets)\n"
  "  message(FATAL_ERROR \"Consumer-local object target did not preserve the extracted implementation source set: \${object_source_sets}\")\n"
  "endif()\n"
  "if(WIN32)\n"
  "  get_target_property(shared_exports proof::rebuilt_shared WINDOWS_EXPORT_ALL_SYMBOLS)\n"
  "  get_target_property(auto_exports proof::rebuilt_auto WINDOWS_EXPORT_ALL_SYMBOLS)\n"
  "  if(NOT shared_exports OR NOT auto_exports)\n"
  "    message(FATAL_ERROR \"Consumer-local shared targets must export symbols on Windows\")\n"
  "  endif()\n"
  "endif()\n"
  "add_executable(static_consumer static.cpp)\n"
  "target_link_libraries(static_consumer PRIVATE proof::rebuilt_static)\n"
  "add_executable(second_static_consumer second_static.cpp)\n"
  "target_link_libraries(second_static_consumer PRIVATE proof::rebuilt_static)\n"
  "add_executable(shared_consumer shared.cpp)\n"
  "target_link_libraries(shared_consumer PRIVATE proof::rebuilt_shared)\n"
  "add_executable(object_consumer object.cpp)\n"
  "target_link_libraries(object_consumer PRIVATE proof::rebuilt_object)\n"
  "add_executable(auto_consumer auto.cpp)\n"
  "target_link_libraries(auto_consumer PRIVATE proof::rebuilt_auto)\n")
file(WRITE "${_tip_consumer_source_dir}/static.cpp"
     "#include <proof/source.hpp>\n#ifndef PUBLIC_VALUE\n#error PUBLIC_VALUE was not forwarded\n#endif\nint main() { return source_value() == 42 && PUBLIC_VALUE == 2 ? 0 : 1; }\n")
file(WRITE "${_tip_consumer_source_dir}/second_static.cpp" "#include <proof/source.hpp>\nint main() { return source_value() == 42 ? 0 : 1; }\n")
file(WRITE "${_tip_consumer_source_dir}/shared.cpp" "#include <proof/modes.hpp>\nint main() { return shared_value() == 43 ? 0 : 1; }\n")
file(WRITE "${_tip_consumer_source_dir}/object.cpp" "#include <proof/modes.hpp>\nint main() { return object_value() == 44 ? 0 : 1; }\n")
file(WRITE "${_tip_consumer_source_dir}/auto.cpp" "#include <proof/modes.hpp>\nint main() { return auto_value() == 45 ? 0 : 1; }\n")

_tip_proof_run_step(
  NAME
  "consumer-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_consumer_source_dir}"
  -B
  "${_tip_consumer_build_dir}"
  -DBUILD_SHARED_LIBS=ON
  ${_tip_toolchain_args})
_tip_proof_run_step(NAME "consumer-build" COMMAND "${CMAKE_COMMAND}" --build "${_tip_consumer_build_dir}")
foreach(_tip_consumer IN ITEMS static_consumer second_static_consumer shared_consumer object_consumer auto_consumer)
  _tip_proof_run_step(NAME "${_tip_consumer}-run" COMMAND "${_tip_consumer_build_dir}/${_tip_consumer}${CMAKE_EXECUTABLE_SUFFIX}")
endforeach()

message(STATUS "[proof] Consumer-local source library proof passed.")
