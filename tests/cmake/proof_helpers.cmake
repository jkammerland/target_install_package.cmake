cmake_minimum_required(VERSION 3.25)

function(_tip_proof_fail text)
  message(FATAL_ERROR "[proof] ${text}")
endfunction()

function(_tip_proof_run_step)
  set(options "")
  set(oneValueArgs NAME)
  set(multiValueArgs COMMAND)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_NAME)
    _tip_proof_fail("_tip_proof_run_step requires NAME")
  endif()
  if(NOT ARG_COMMAND)
    _tip_proof_fail("_tip_proof_run_step requires COMMAND")
  endif()

  execute_process(
    COMMAND ${ARG_COMMAND}
    RESULT_VARIABLE _tip_result
    OUTPUT_VARIABLE _tip_stdout
    ERROR_VARIABLE _tip_stderr)

  if(NOT _tip_result EQUAL 0)
    message(STATUS "[proof] Step '${ARG_NAME}' failed.")
    if(NOT _tip_stdout STREQUAL "")
      message(STATUS "[proof][stdout]\n${_tip_stdout}")
    endif()
    if(NOT _tip_stderr STREQUAL "")
      message(STATUS "[proof][stderr]\n${_tip_stderr}")
    endif()
    _tip_proof_fail("Step '${ARG_NAME}' exited with code ${_tip_result}")
  endif()
endfunction()

function(_tip_proof_expect_failure)
  set(options "")
  set(oneValueArgs NAME)
  set(multiValueArgs COMMAND EXPECT_CONTAINS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_NAME)
    _tip_proof_fail("_tip_proof_expect_failure requires NAME")
  endif()
  if(NOT ARG_COMMAND)
    _tip_proof_fail("_tip_proof_expect_failure requires COMMAND")
  endif()

  execute_process(
    COMMAND ${ARG_COMMAND}
    RESULT_VARIABLE _tip_result
    OUTPUT_VARIABLE _tip_stdout
    ERROR_VARIABLE _tip_stderr)

  if(_tip_result EQUAL 0)
    if(NOT _tip_stdout STREQUAL "")
      message(STATUS "[proof][stdout]\n${_tip_stdout}")
    endif()
    if(NOT _tip_stderr STREQUAL "")
      message(STATUS "[proof][stderr]\n${_tip_stderr}")
    endif()
    _tip_proof_fail("Step '${ARG_NAME}' unexpectedly succeeded")
  endif()

  set(_tip_combined_output "${_tip_stdout}\n${_tip_stderr}")
  foreach(_tip_expected IN LISTS ARG_EXPECT_CONTAINS)
    string(FIND "${_tip_combined_output}" "${_tip_expected}" _tip_match_index)
    if(_tip_match_index EQUAL -1)
      message(STATUS "[proof][stdout]\n${_tip_stdout}")
      message(STATUS "[proof][stderr]\n${_tip_stderr}")
      _tip_proof_fail("Expected '${_tip_expected}' in output of '${ARG_NAME}'")
    endif()
  endforeach()
endfunction()

function(_tip_proof_assert_exists path)
  if(NOT EXISTS "${path}")
    _tip_proof_fail("Expected path to exist: ${path}")
  endif()
endfunction()

function(_tip_proof_assert_not_exists path)
  if(EXISTS "${path}")
    _tip_proof_fail("Expected path to be absent: ${path}")
  endif()
endfunction()

function(_tip_proof_assert_file_contains path needle)
  _tip_proof_assert_exists("${path}")
  file(READ "${path}" _tip_content)
  string(FIND "${_tip_content}" "${needle}" _tip_match_index)
  if(_tip_match_index EQUAL -1)
    _tip_proof_fail("Expected to find '${needle}' in '${path}'")
  endif()
endfunction()

function(_tip_proof_assert_file_not_contains path needle)
  _tip_proof_assert_exists("${path}")
  file(READ "${path}" _tip_content)
  string(FIND "${_tip_content}" "${needle}" _tip_match_index)
  if(NOT _tip_match_index EQUAL -1)
    _tip_proof_fail("Did not expect to find '${needle}' in '${path}'")
  endif()
endfunction()

function(_tip_proof_read_json path out_var)
  _tip_proof_assert_exists("${path}")
  file(READ "${path}" _tip_json_content)
  set(${out_var}
      "${_tip_json_content}"
      PARENT_SCOPE)
endfunction()

function(_tip_proof_assert_json_path_string path expected)
  set(_tip_json_path ${ARGN})
  if(NOT _tip_json_path)
    _tip_proof_fail("_tip_proof_assert_json_path_string requires at least one JSON path element")
  endif()

  _tip_proof_read_json("${path}" _tip_json_content)
  string(
    JSON
    _tip_json_actual
    ERROR_VARIABLE
    _tip_json_error
    GET
    "${_tip_json_content}"
    ${_tip_json_path})
  if(_tip_json_error)
    _tip_proof_fail("Expected JSON path '${_tip_json_path}' in '${path}': ${_tip_json_error}")
  endif()
  if(NOT "${_tip_json_actual}" STREQUAL "${expected}")
    _tip_proof_fail("Expected JSON path '${_tip_json_path}' in '${path}' to be '${expected}', got '${_tip_json_actual}'")
  endif()
endfunction()

function(_tip_proof_assert_json_path_length path expected)
  set(_tip_json_path ${ARGN})
  if(NOT _tip_json_path)
    _tip_proof_fail("_tip_proof_assert_json_path_length requires at least one JSON path element")
  endif()

  _tip_proof_read_json("${path}" _tip_json_content)
  string(
    JSON
    _tip_json_length
    ERROR_VARIABLE
    _tip_json_error
    LENGTH
    "${_tip_json_content}"
    ${_tip_json_path})
  if(_tip_json_error)
    _tip_proof_fail("Expected JSON array/object path '${_tip_json_path}' in '${path}': ${_tip_json_error}")
  endif()
  if(NOT _tip_json_length EQUAL ${expected})
    _tip_proof_fail("Expected JSON path '${_tip_json_path}' in '${path}' to have length ${expected}, got ${_tip_json_length}")
  endif()
endfunction()

function(_tip_proof_find_spdx_document path name out_var)
  _tip_proof_read_json("${path}" _tip_json_content)
  string(JSON _tip_graph_length ERROR_VARIABLE _tip_json_error LENGTH "${_tip_json_content}" "@graph")
  if(_tip_json_error)
    _tip_proof_fail("Expected JSON graph in '${path}': ${_tip_json_error}")
  endif()

  math(EXPR _tip_last_index "${_tip_graph_length} - 1")
  foreach(_tip_index RANGE 0 ${_tip_last_index})
    string(
      JSON
      _tip_type
      ERROR_VARIABLE
      _tip_type_error
      GET
      "${_tip_json_content}"
      "@graph"
      ${_tip_index}
      "type")
    if(_tip_type_error OR NOT "${_tip_type}" STREQUAL "SpdxDocument")
      continue()
    endif()

    string(
      JSON
      _tip_name
      ERROR_VARIABLE
      _tip_name_error
      GET
      "${_tip_json_content}"
      "@graph"
      ${_tip_index}
      "name")
    if(NOT _tip_name_error AND "${_tip_name}" STREQUAL "${name}")
      set(${out_var}
          "${_tip_index}"
          PARENT_SCOPE)
      return()
    endif()
  endforeach()

  _tip_proof_fail("Expected SPDX document '${name}' in '${path}'")
endfunction()

function(_tip_proof_assert_root_element_names path document_index)
  set(_tip_expected_names ${ARGN})
  if(NOT _tip_expected_names)
    _tip_proof_fail("_tip_proof_assert_root_element_names requires at least one expected root name")
  endif()

  _tip_proof_read_json("${path}" _tip_json_content)
  string(JSON _tip_root_length ERROR_VARIABLE _tip_root_error LENGTH "${_tip_json_content}" "@graph" ${document_index} "rootElement")
  if(_tip_root_error)
    _tip_proof_fail("Expected rootElement array in '${path}': ${_tip_root_error}")
  endif()

  list(LENGTH _tip_expected_names _tip_expected_count)
  if(NOT _tip_root_length EQUAL _tip_expected_count)
    _tip_proof_fail("Expected ${_tip_expected_count} root elements in '${path}', got ${_tip_root_length}")
  endif()

  set(_tip_actual_names "")
  math(EXPR _tip_last_index "${_tip_root_length} - 1")
  foreach(_tip_index RANGE 0 ${_tip_last_index})
    string(
      JSON
      _tip_name
      ERROR_VARIABLE
      _tip_name_error
      GET
      "${_tip_json_content}"
      "@graph"
      ${document_index}
      "rootElement"
      ${_tip_index}
      "name")
    if(_tip_name_error)
      _tip_proof_fail("Expected rootElement name in '${path}': ${_tip_name_error}")
    endif()
    list(APPEND _tip_actual_names "${_tip_name}")
  endforeach()

  set(_tip_sorted_expected ${_tip_expected_names})
  set(_tip_sorted_actual ${_tip_actual_names})
  list(SORT _tip_sorted_expected)
  list(SORT _tip_sorted_actual)

  if(NOT "${_tip_sorted_actual}" STREQUAL "${_tip_sorted_expected}")
    _tip_proof_fail("Expected rootElement names '${_tip_sorted_expected}' in '${path}', got '${_tip_sorted_actual}'")
  endif()
endfunction()

function(_tip_proof_find_root_element path document_index root_name out_var)
  _tip_proof_read_json("${path}" _tip_json_content)
  string(JSON _tip_root_length ERROR_VARIABLE _tip_root_error LENGTH "${_tip_json_content}" "@graph" ${document_index} "rootElement")
  if(_tip_root_error)
    _tip_proof_fail("Expected rootElement array in '${path}': ${_tip_root_error}")
  endif()

  math(EXPR _tip_last_index "${_tip_root_length} - 1")
  foreach(_tip_index RANGE 0 ${_tip_last_index})
    string(
      JSON
      _tip_name
      ERROR_VARIABLE
      _tip_name_error
      GET
      "${_tip_json_content}"
      "@graph"
      ${document_index}
      "rootElement"
      ${_tip_index}
      "name")
    if(NOT _tip_name_error AND "${_tip_name}" STREQUAL "${root_name}")
      set(${out_var}
          "${_tip_index}"
          PARENT_SCOPE)
      return()
    endif()
  endforeach()

  _tip_proof_fail("Expected root element '${root_name}' in '${path}'")
endfunction()

function(_tip_proof_assert_root_element_json_path_string path document_index root_name expected)
  set(_tip_root_json_path ${ARGN})
  if(NOT _tip_root_json_path)
    _tip_proof_fail("_tip_proof_assert_root_element_json_path_string requires at least one root JSON path element")
  endif()

  _tip_proof_find_root_element("${path}" "${document_index}" "${root_name}" _tip_root_index)
  _tip_proof_assert_json_path_string(
    "${path}"
    "${expected}"
    "@graph"
    ${document_index}
    "rootElement"
    ${_tip_root_index}
    ${_tip_root_json_path})
endfunction()

function(_tip_proof_assert_root_element_json_path_absent path document_index root_name)
  set(_tip_root_json_path ${ARGN})
  if(NOT _tip_root_json_path)
    _tip_proof_fail("_tip_proof_assert_root_element_json_path_absent requires at least one root JSON path element")
  endif()

  _tip_proof_find_root_element("${path}" "${document_index}" "${root_name}" _tip_root_index)
  _tip_proof_read_json("${path}" _tip_json_content)
  string(
    JSON
    _tip_json_actual
    ERROR_VARIABLE
    _tip_json_error
    GET
    "${_tip_json_content}"
    "@graph"
    ${document_index}
    "rootElement"
    ${_tip_root_index}
    ${_tip_root_json_path})
  if(NOT _tip_json_error)
    _tip_proof_fail("Did not expect JSON path '${_tip_root_json_path}' on root element '${root_name}' in '${path}', got '${_tip_json_actual}'")
  endif()
endfunction()

function(_tip_proof_assert_root_element path document_index root_name expected_version expected_homepage)
  _tip_proof_read_json("${path}" _tip_json_content)
  string(JSON _tip_root_length ERROR_VARIABLE _tip_root_error LENGTH "${_tip_json_content}" "@graph" ${document_index} "rootElement")
  if(_tip_root_error)
    _tip_proof_fail("Expected rootElement array in '${path}': ${_tip_root_error}")
  endif()

  math(EXPR _tip_last_index "${_tip_root_length} - 1")
  foreach(_tip_index RANGE 0 ${_tip_last_index})
    string(
      JSON
      _tip_name
      ERROR_VARIABLE
      _tip_name_error
      GET
      "${_tip_json_content}"
      "@graph"
      ${document_index}
      "rootElement"
      ${_tip_index}
      "name")
    if(_tip_name_error OR NOT "${_tip_name}" STREQUAL "${root_name}")
      continue()
    endif()

    _tip_proof_assert_json_path_string(
      "${path}"
      "${expected_version}"
      "@graph"
      ${document_index}
      "rootElement"
      ${_tip_index}
      "software_packageVersion")
    _tip_proof_assert_json_path_string(
      "${path}"
      "${expected_homepage}"
      "@graph"
      ${document_index}
      "rootElement"
      ${_tip_index}
      "software_homePage")
    return()
  endforeach()

  _tip_proof_fail("Expected root element '${root_name}' in '${path}'")
endfunction()

function(_tip_proof_append_toolchain_args out_var)
  set(_tip_args "")

  if(DEFINED TIP_CMAKE_GENERATOR AND NOT TIP_CMAKE_GENERATOR STREQUAL "")
    list(APPEND _tip_args -G "${TIP_CMAKE_GENERATOR}")
  endif()
  if(DEFINED TIP_CMAKE_MAKE_PROGRAM AND NOT TIP_CMAKE_MAKE_PROGRAM STREQUAL "")
    list(APPEND _tip_args "-DCMAKE_MAKE_PROGRAM=${TIP_CMAKE_MAKE_PROGRAM}")
  endif()
  if(DEFINED TIP_C_COMPILER AND NOT TIP_C_COMPILER STREQUAL "")
    list(APPEND _tip_args "-DCMAKE_C_COMPILER=${TIP_C_COMPILER}")
  endif()
  if(DEFINED TIP_CXX_COMPILER AND NOT TIP_CXX_COMPILER STREQUAL "")
    list(APPEND _tip_args "-DCMAKE_CXX_COMPILER=${TIP_CXX_COMPILER}")
  endif()
  if(DEFINED TIP_CMAKE_TOOLCHAIN_FILE AND NOT TIP_CMAKE_TOOLCHAIN_FILE STREQUAL "")
    list(APPEND _tip_args "-DCMAKE_TOOLCHAIN_FILE=${TIP_CMAKE_TOOLCHAIN_FILE}")
  endif()
  if(DEFINED TIP_CMAKE_GENERATOR_PLATFORM AND NOT TIP_CMAKE_GENERATOR_PLATFORM STREQUAL "")
    list(APPEND _tip_args -A "${TIP_CMAKE_GENERATOR_PLATFORM}")
  endif()
  if(DEFINED TIP_CMAKE_GENERATOR_TOOLSET AND NOT TIP_CMAKE_GENERATOR_TOOLSET STREQUAL "")
    list(APPEND _tip_args -T "${TIP_CMAKE_GENERATOR_TOOLSET}")
  endif()

  set(${out_var}
      "${_tip_args}"
      PARENT_SCOPE)
endfunction()
