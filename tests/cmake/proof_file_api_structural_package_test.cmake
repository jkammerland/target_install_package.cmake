cmake_minimum_required(VERSION 4.4)

include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

if(NOT DEFINED TIP_REPO_ROOT)
  _tip_proof_fail("TIP_REPO_ROOT is required")
endif()
if(NOT DEFINED TIP_PROOF_TEST_ROOT)
  _tip_proof_fail("TIP_PROOF_TEST_ROOT is required")
endif()

function(_tip_file_api_get json out_var)
  string(JSON _tip_value ERROR_VARIABLE _tip_error GET "${json}" ${ARGN})
  if(_tip_error)
    _tip_proof_fail("Missing File API JSON path '${ARGN}': ${_tip_error}")
  endif()
  set(${out_var}
      "${_tip_value}"
      PARENT_SCOPE)
endfunction()

function(_tip_file_api_find_target codemodel reply_dir target_name out_var)
  foreach(_tip_target_group IN ITEMS targets abstractTargets)
    string(JSON _tip_target_count ERROR_VARIABLE _tip_count_error LENGTH "${codemodel}" configurations 0 ${_tip_target_group})
    if(_tip_count_error)
      continue()
    endif()

    math(EXPR _tip_last_target_index "${_tip_target_count} - 1")
    foreach(_tip_target_index RANGE 0 ${_tip_last_target_index})
      _tip_file_api_get("${codemodel}" _tip_name configurations 0 ${_tip_target_group} ${_tip_target_index} name)
      if(NOT "${_tip_name}" STREQUAL "${target_name}")
        continue()
      endif()

      _tip_file_api_get("${codemodel}" _tip_target_json_file configurations 0 ${_tip_target_group} ${_tip_target_index} jsonFile)
      file(READ "${reply_dir}/${_tip_target_json_file}" _tip_target_json)
      set(${out_var}
          "${_tip_target_json}"
          PARENT_SCOPE)
      return()
    endforeach()
  endforeach()

  _tip_proof_fail("Missing File API target '${target_name}'")
endfunction()

function(_tip_file_api_assert_imported target_json target_name)
  _tip_file_api_get("${target_json}" _tip_imported imported)
  if(NOT _tip_imported)
    _tip_proof_fail("Expected '${target_name}' to be an imported File API target")
  endif()
endfunction()

function(_tip_file_api_get_target_id target_json out_var)
  _tip_file_api_get("${target_json}" _tip_target_id id)
  set(${out_var}
      "${_tip_target_id}"
      PARENT_SCOPE)
endfunction()

function(_tip_file_api_assert_target_edge target_json member expected_id target_name)
  string(JSON _tip_edge_count ERROR_VARIABLE _tip_edge_error LENGTH "${target_json}" ${member})
  if(_tip_edge_error)
    _tip_proof_fail("Expected '${target_name}' to expose '${member}' in the File API")
  endif()

  math(EXPR _tip_last_edge_index "${_tip_edge_count} - 1")
  foreach(_tip_edge_index RANGE 0 ${_tip_last_edge_index})
    string(JSON _tip_edge_id ERROR_VARIABLE _tip_edge_id_error GET "${target_json}" ${member} ${_tip_edge_index} id)
    if(NOT _tip_edge_id_error AND "${_tip_edge_id}" STREQUAL "${expected_id}")
      return()
    endif()
  endforeach()

  _tip_proof_fail("Expected '${target_name}' to reference target id '${expected_id}' through '${member}'")
endfunction()

function(_tip_file_api_assert_path_under_prefix path prefix description)
  string(FIND "${path}" "${prefix}/" _tip_prefix_index)
  if(NOT _tip_prefix_index EQUAL 0)
    _tip_proof_fail("${description} escaped the relocated prefix: ${path}")
  endif()
endfunction()

function(_tip_file_api_assert_file_set target_json set_name set_type install_prefix)
  string(JSON _tip_file_set_count ERROR_VARIABLE _tip_file_set_error LENGTH "${target_json}" fileSets)
  if(_tip_file_set_error)
    _tip_proof_fail("Expected File API file-set metadata for '${set_name}'")
  endif()

  math(EXPR _tip_last_file_set_index "${_tip_file_set_count} - 1")
  foreach(_tip_file_set_index RANGE 0 ${_tip_last_file_set_index})
    _tip_file_api_get("${target_json}" _tip_actual_name fileSets ${_tip_file_set_index} name)
    if(NOT "${_tip_actual_name}" STREQUAL "${set_name}")
      continue()
    endif()

    _tip_file_api_get("${target_json}" _tip_actual_type fileSets ${_tip_file_set_index} type)
    _tip_file_api_get("${target_json}" _tip_visibility fileSets ${_tip_file_set_index} visibility)
    if(NOT "${_tip_actual_type}" STREQUAL "${set_type}" OR NOT "${_tip_visibility}" STREQUAL "INTERFACE")
      _tip_proof_fail("Unexpected metadata for file set '${set_name}': type='${_tip_actual_type}', visibility='${_tip_visibility}'")
    endif()

    string(JSON _tip_base_directory_count LENGTH "${target_json}" fileSets ${_tip_file_set_index} baseDirectories)
    math(EXPR _tip_last_base_directory_index "${_tip_base_directory_count} - 1")
    foreach(_tip_base_directory_index RANGE 0 ${_tip_last_base_directory_index})
      _tip_file_api_get("${target_json}" _tip_base_directory fileSets ${_tip_file_set_index} baseDirectories ${_tip_base_directory_index})
      _tip_file_api_assert_path_under_prefix("${_tip_base_directory}" "${install_prefix}" "File-set base directory")
    endforeach()
    return()
  endforeach()

  _tip_proof_fail("Missing File API file set '${set_name}'")
endfunction()

function(_tip_file_api_assert_interface_sources_under_prefix target_json install_prefix)
  string(JSON _tip_source_count ERROR_VARIABLE _tip_source_error LENGTH "${target_json}" interfaceSources)
  if(_tip_source_error)
    _tip_proof_fail("Expected File API interface-source metadata")
  endif()

  math(EXPR _tip_last_source_index "${_tip_source_count} - 1")
  foreach(_tip_source_index RANGE 0 ${_tip_last_source_index})
    _tip_file_api_get("${target_json}" _tip_source_path interfaceSources ${_tip_source_index} path)
    _tip_file_api_assert_path_under_prefix("${_tip_source_path}" "${install_prefix}" "Interface source")
  endforeach()
endfunction()

function(_tip_file_api_executable_path build_dir configuration executable_name out_var)
  file(STRINGS "${build_dir}/CMakeCache.txt" _tip_configuration_types REGEX "^CMAKE_CONFIGURATION_TYPES:[^=]*=")
  set(_tip_executable_path "${build_dir}/${executable_name}")
  if(_tip_configuration_types)
    set(_tip_executable_path "${build_dir}/${configuration}/${executable_name}")
  endif()
  set(${out_var}
      "${_tip_executable_path}"
      PARENT_SCOPE)
endfunction()

set(_tip_case_root "${TIP_PROOF_TEST_ROOT}/file-api-structural-package")
set(_tip_fixture_source_dir "${_tip_case_root}/fixture-src")
set(_tip_fixture_build_dir "${_tip_case_root}/fixture-build")
set(_tip_install_prefix "${_tip_case_root}/fixture-install")
set(_tip_consumer_source_dir "${_tip_case_root}/consumer-src")
set(_tip_consumer_build_dir "${_tip_case_root}/consumer-build")
set(_tip_build_config "Release")

file(REMOVE_RECURSE "${_tip_case_root}")
file(MAKE_DIRECTORY "${_tip_fixture_source_dir}/include/file_api" "${_tip_fixture_source_dir}/src")
file(WRITE "${_tip_fixture_source_dir}/include/file_api/api.hpp" "#pragma once\nint file_api_value();\n")
file(WRITE "${_tip_fixture_source_dir}/src/api.cpp" "#include <file_api/api.hpp>\nint file_api_value() { return 42; }\n")
file(WRITE "${_tip_fixture_source_dir}/src/file_api_module.cppm" "export module file_api_module;\nexport int file_api_module_value() { return 7; }\n")
file(
  WRITE "${_tip_fixture_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.4)\n"
  "project(proof_file_api_package VERSION 1.0.0 LANGUAGES CXX)\n"
  "set(TARGET_INSTALL_PACKAGE_DISABLE_INSTALL ON)\n"
  "include(\"${TIP_REPO_ROOT}/examples/check_cxx_modules_support.cmake\")\n"
  "check_cxx_modules_support(TIP_MODULES_SUPPORTED)\n"
  "file(WRITE \"\${CMAKE_BINARY_DIR}/modules-supported.cmake\" \"set(TIP_MODULES_SUPPORTED \${TIP_MODULES_SUPPORTED})\\n\")\n"
  "include(\"${TIP_REPO_ROOT}/cmake/load_target_install_package.cmake\")\n"
  "add_library(file_api_dependency INTERFACE)\n"
  "target_compile_definitions(file_api_dependency INTERFACE FILE_API_DEPENDENCY=1)\n"
  "target_install_package(file_api_dependency EXPORT_NAME file_api_pkg NAMESPACE FileApi:: VERSION \${PROJECT_VERSION})\n"
  "add_library(file_api_source INTERFACE)\n"
  "target_sources(file_api_source INTERFACE FILE_SET headers TYPE HEADERS BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/include\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/include/file_api/api.hpp\")\n"
  "target_sources(file_api_source INTERFACE FILE_SET implementation TYPE SOURCES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"\${CMAKE_CURRENT_SOURCE_DIR}/src/api.cpp\")\n"
  "target_link_libraries(file_api_source INTERFACE file_api_dependency)\n"
  "target_install_package(file_api_source EXPORT_NAME file_api_pkg NAMESPACE FileApi:: VERSION \${PROJECT_VERSION})\n"
  "if(TIP_MODULES_SUPPORTED)\n"
  "  add_library(file_api_module STATIC)\n"
  "  target_compile_features(file_api_module PUBLIC cxx_std_20)\n"
  "  target_sources(file_api_module PUBLIC FILE_SET CXX_MODULES BASE_DIRS \"\${CMAKE_CURRENT_SOURCE_DIR}/src\" FILES \"src/file_api_module.cppm\")\n"
  "  set_target_properties(file_api_module PROPERTIES CXX_SCAN_FOR_MODULES ON)\n"
  "  target_install_package(file_api_module EXPORT_NAME file_api_pkg NAMESPACE FileApi:: VERSION \${PROJECT_VERSION})\n"
  "endif()\n")

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
  "-DCMAKE_BUILD_TYPE=${_tip_build_config}"
  ${_tip_toolchain_args})
include("${_tip_fixture_build_dir}/modules-supported.cmake")
_tip_proof_run_step(NAME "fixture-build" COMMAND "${CMAKE_COMMAND}" --build "${_tip_fixture_build_dir}" --config "${_tip_build_config}")
_tip_proof_run_step(
  NAME
  "fixture-install"
  COMMAND
  "${CMAKE_COMMAND}"
  --install
  "${_tip_fixture_build_dir}"
  --config
  "${_tip_build_config}"
  --prefix
  "${_tip_install_prefix}")

file(REMOVE_RECURSE "${_tip_fixture_source_dir}" "${_tip_fixture_build_dir}")
file(MAKE_DIRECTORY "${_tip_consumer_source_dir}" "${_tip_consumer_build_dir}/.cmake/api/v1/query/client-target-install-package")
file(WRITE "${_tip_consumer_build_dir}/.cmake/api/v1/query/client-target-install-package/codemodel-v2" "")
file(
  WRITE "${_tip_consumer_source_dir}/CMakeLists.txt"
  "cmake_minimum_required(VERSION 4.4)\n"
  "project(proof_file_api_consumer LANGUAGES CXX)\n"
  "find_package(file_api_pkg 1.0 CONFIG REQUIRED PATHS \"${_tip_install_prefix}\" NO_DEFAULT_PATH)\n"
  "add_executable(file_api_consumer main.cpp)\n"
  "target_link_libraries(file_api_consumer PRIVATE FileApi::file_api_source)\n")
file(WRITE "${_tip_consumer_source_dir}/main.cpp" "#include <file_api/api.hpp>\nint main() { return file_api_value() == 42 ? 0 : 1; }\n")

_tip_proof_run_step(
  NAME
  "consumer-configure"
  COMMAND
  "${CMAKE_COMMAND}"
  -S
  "${_tip_consumer_source_dir}"
  -B
  "${_tip_consumer_build_dir}"
  "-DCMAKE_BUILD_TYPE=${_tip_build_config}"
  ${_tip_toolchain_args})

set(_tip_reply_dir "${_tip_consumer_build_dir}/.cmake/api/v1/reply")
file(GLOB _tip_reply_indexes LIST_DIRECTORIES FALSE "${_tip_reply_dir}/index-*.json")
list(SORT _tip_reply_indexes)
list(LENGTH _tip_reply_indexes _tip_reply_index_count)
if(NOT _tip_reply_index_count EQUAL 1)
  _tip_proof_fail("Expected exactly one File API reply index, got ${_tip_reply_index_count}")
endif()
list(GET _tip_reply_indexes 0 _tip_reply_index)
file(READ "${_tip_reply_index}" _tip_index_json)

string(JSON _tip_object_count LENGTH "${_tip_index_json}" objects)
set(_tip_codemodel_json_file "")
math(EXPR _tip_last_object_index "${_tip_object_count} - 1")
foreach(_tip_object_index RANGE 0 ${_tip_last_object_index})
  _tip_file_api_get("${_tip_index_json}" _tip_object_kind objects ${_tip_object_index} kind)
  if("${_tip_object_kind}" STREQUAL "codemodel")
    _tip_file_api_get("${_tip_index_json}" _tip_codemodel_json_file objects ${_tip_object_index} jsonFile)
    break()
  endif()
endforeach()
if("${_tip_codemodel_json_file}" STREQUAL "")
  _tip_proof_fail("Missing codemodel in File API reply index")
endif()
file(READ "${_tip_reply_dir}/${_tip_codemodel_json_file}" _tip_codemodel_json)

_tip_file_api_find_target("${_tip_codemodel_json}" "${_tip_reply_dir}" "file_api_consumer" _tip_consumer_target_json)
_tip_file_api_find_target("${_tip_codemodel_json}" "${_tip_reply_dir}" "FileApi::file_api_source" _tip_source_target_json)
_tip_file_api_find_target("${_tip_codemodel_json}" "${_tip_reply_dir}" "FileApi::file_api_dependency" _tip_dependency_target_json)

_tip_file_api_assert_imported("${_tip_source_target_json}" "FileApi::file_api_source")
_tip_file_api_assert_imported("${_tip_dependency_target_json}" "FileApi::file_api_dependency")
_tip_file_api_get_target_id("${_tip_source_target_json}" _tip_source_target_id)
_tip_file_api_get_target_id("${_tip_dependency_target_json}" _tip_dependency_target_id)
_tip_file_api_assert_target_edge("${_tip_consumer_target_json}" linkLibraries "${_tip_source_target_id}" "file_api_consumer")
_tip_file_api_assert_target_edge("${_tip_source_target_json}" interfaceLinkLibraries "${_tip_dependency_target_id}" "FileApi::file_api_source")
_tip_file_api_assert_file_set("${_tip_source_target_json}" "headers" "HEADERS" "${_tip_install_prefix}")
_tip_file_api_assert_file_set("${_tip_source_target_json}" "implementation" "SOURCES" "${_tip_install_prefix}")
_tip_file_api_assert_interface_sources_under_prefix("${_tip_source_target_json}" "${_tip_install_prefix}")
if(TIP_MODULES_SUPPORTED)
  _tip_file_api_find_target("${_tip_codemodel_json}" "${_tip_reply_dir}" "FileApi::file_api_module" _tip_module_target_json)
  _tip_file_api_assert_imported("${_tip_module_target_json}" "FileApi::file_api_module")
  _tip_file_api_assert_file_set("${_tip_module_target_json}" "CXX_MODULES" "CXX_MODULES" "${_tip_install_prefix}")
else()
  message(STATUS "[proof] Skipping File API C++ module metadata proof because this toolchain does not support C++20 modules.")
endif()

file(GLOB _tip_reply_files LIST_DIRECTORIES FALSE "${_tip_reply_dir}/*.json")
foreach(_tip_reply_file IN LISTS _tip_reply_files)
  file(READ "${_tip_reply_file}" _tip_reply_content)
  string(FIND "${_tip_reply_content}" "${_tip_fixture_source_dir}" _tip_source_leak_index)
  string(FIND "${_tip_reply_content}" "${_tip_fixture_build_dir}" _tip_build_leak_index)
  if(NOT _tip_source_leak_index EQUAL -1 OR NOT _tip_build_leak_index EQUAL -1)
    _tip_proof_fail("Producer path leaked into File API reply '${_tip_reply_file}'")
  endif()
endforeach()

_tip_proof_run_step(NAME "consumer-build" COMMAND "${CMAKE_COMMAND}" --build "${_tip_consumer_build_dir}" --config "${_tip_build_config}")
_tip_file_api_executable_path("${_tip_consumer_build_dir}" "${_tip_build_config}" "file_api_consumer${CMAKE_EXECUTABLE_SUFFIX}" _tip_consumer_executable)
_tip_proof_run_step(NAME "consumer-run" COMMAND "${_tip_consumer_executable}")

message(STATUS "[proof] File API structural package proof passed.")
