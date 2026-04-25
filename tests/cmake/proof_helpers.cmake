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
