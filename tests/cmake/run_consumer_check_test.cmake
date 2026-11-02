cmake_minimum_required(VERSION 3.25)
include("${CMAKE_CURRENT_LIST_DIR}/proof_helpers.cmake")

# Every invocation gets its own evidence directory, including parallel CTest runs.
string(
  RANDOM
  LENGTH 12
  ALPHABET 0123456789abcdef _tip_case_id)
set(_tip_case "${TIP_CHECK_TEST_ROOT}/${TIP_CHECK_CASE}-${_tip_case_id}")
set(_tip_work_root "${_tip_case}/runs")
file(MAKE_DIRECTORY "${_tip_case}")
file(MAKE_DIRECTORY "${_tip_case}/runs")
file(WRITE "${_tip_case}/runs/keep.txt" "existing user data\n")
set(_tip_settings "${_tip_case}/settings.cmake")
_tip_proof_append_toolchain_args(_tip_toolchain_args)
file(
  WRITE "${_tip_settings}"
  "set(TIP_CHECK_PRODUCER [==[${TIP_REPO_ROOT}/tests/installed-consumer-check/producer]==])\n"
  "set(TIP_CHECK_CONSUMER [==[${TIP_REPO_ROOT}/tests/installed-consumer-check/consumer]==])\n"
  "set(TIP_CHECK_PACKAGE answer)\n"
  "set(TIP_CHECK_WORK_ROOT [====[${_tip_work_root}]====])\n"
  "set(TIP_CHECK_CONFIG Release)\n"
  "set(TIP_CHECK_PRODUCER_ARGS [==[-DTIP_REPO_ROOT=${TIP_REPO_ROOT};${_tip_toolchain_args}]==])\n"
  "set(TIP_CHECK_CONSUMER_ARGS [==[${_tip_toolchain_args}]==])\n")

set(_tip_expected_failure "")
if(TIP_CHECK_CASE STREQUAL "missing-dependency")
  file(APPEND "${_tip_settings}" "list(APPEND TIP_CHECK_PRODUCER_ARGS -DTIP_BROKEN_DEPENDENCY=ON)\n")
  set(_tip_expected_failure "installed-configure failed;tip_check_dependency::value")
elseif(TIP_CHECK_CASE STREQUAL "broken-relocation")
  file(APPEND "${_tip_settings}" "list(APPEND TIP_CHECK_PRODUCER_ARGS -DTIP_BROKEN_RELOCATION=ON)\n")
  set(_tip_expected_failure "relocated-configure failed;non-existent path")
elseif(TIP_CHECK_CASE STREQUAL "no-tests")
  file(APPEND "${_tip_settings}" "list(APPEND TIP_CHECK_CONSUMER_ARGS -DTIP_NO_TESTS=ON)\nset(TIP_CHECK_RUN_TESTS ON)\n")
  set(_tip_expected_failure "installed-test failed;No tests were found")
elseif(TIP_CHECK_CASE MATCHES "^cross-" OR TIP_CHECK_CASE STREQUAL "bracket-values")
  file(APPEND "${_tip_settings}" "list(APPEND TIP_CHECK_PRODUCER_ARGS -DCMAKE_SYSTEM_NAME=Generic)\nlist(APPEND TIP_CHECK_CONSUMER_ARGS -DCMAKE_SYSTEM_NAME=Generic)\n")
  if(TIP_CHECK_CASE STREQUAL "cross-emulator" OR TIP_CHECK_CASE STREQUAL "bracket-values")
    file(APPEND "${_tip_settings}"
         "set(TIP_CHECK_EMULATOR [====[${CMAKE_COMMAND};-E;env;TIP_CHECK_EMULATED=1;TIP_CHECK_DELIMITERS=]=]-]==]-]===]]====])\nlist(APPEND TIP_CHECK_CONSUMER_ARGS -DTIP_EXPECT_EMULATOR=ON)\n")
    if(TIP_CHECK_CASE STREQUAL "bracket-values")
      file(APPEND "${_tip_settings}" "set(TIP_CHECK_PREFIX_PATH [====[${_tip_case}/sdk]=]-]==]-]===]prefix]====])\n")
    endif()
  else()
    # An accidental runtime attempt must fail instead of silently passing.
    file(APPEND "${_tip_settings}" "list(APPEND TIP_CHECK_CONSUMER_ARGS -DTIP_NO_TESTS=ON)\n")
  endif()
  if(TIP_CHECK_CASE STREQUAL "cross-rooted")
    set(_tip_dependency_prefix "${_tip_case}/dependency-prefix")
    set(_tip_rooted_dependency "${_tip_case}/sysroot${_tip_dependency_prefix}/share/cmake/tip_check_rooted")
    file(MAKE_DIRECTORY "${_tip_rooted_dependency}" "${_tip_dependency_prefix}/share/cmake/tip_check_rooted")
    file(WRITE "${_tip_rooted_dependency}/tip_check_rootedConfig.cmake" "add_library(tip_check_rooted::value INTERFACE IMPORTED)\n")
    file(WRITE "${_tip_dependency_prefix}/share/cmake/tip_check_rooted/tip_check_rootedConfig.cmake" "message(FATAL_ERROR \"Host dependency must not satisfy a rooted dependency search\")\n")
    file(WRITE "${_tip_case}/toolchain.cmake" "set(CMAKE_SYSTEM_NAME Generic)\nset(CMAKE_FIND_ROOT_PATH [==[${_tip_case}/sysroot]==])\nset(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)\n")
    file(APPEND "${_tip_settings}" "set(TIP_CHECK_TOOLCHAIN_FILE [==[${_tip_case}/toolchain.cmake]==])\n" "set(TIP_CHECK_PREFIX_PATH [==[${_tip_dependency_prefix}]==])\n"
                                   "list(APPEND TIP_CHECK_PRODUCER_ARGS -DTIP_REQUIRE_ROOTED_DEPENDENCY=ON [==[-DCMAKE_PREFIX_PATH=${_tip_dependency_prefix}]==])\n")
  endif()
elseif(TIP_CHECK_CASE STREQUAL "outside-prefix")
  file(MAKE_DIRECTORY "${_tip_case}/ambient")
  file(WRITE "${_tip_case}/ambient/answerConfig.cmake" "add_library(answer::answer INTERFACE IMPORTED)\n")
  file(APPEND "${_tip_settings}" "list(APPEND TIP_CHECK_CONSUMER_ARGS [==[-Danswer_DIR=${_tip_case}/ambient]==])\n")
  set(_tip_expected_failure "answer resolved outside the tested prefix")
elseif(NOT TIP_CHECK_CASE STREQUAL "success")
  _tip_proof_fail("Unknown consumer-check case: ${TIP_CHECK_CASE}")
endif()

execute_process(
  COMMAND "${CMAKE_COMMAND}" "-DTIP_CHECK_SETTINGS=${_tip_settings}" -P "${TIP_REPO_ROOT}/cmake/check_installed_consumer.cmake"
  RESULT_VARIABLE _tip_result
  OUTPUT_VARIABLE _tip_stdout
  ERROR_VARIABLE _tip_stderr)
file(WRITE "${_tip_case}/check.log" "${_tip_stdout}\n${_tip_stderr}")
_tip_proof_assert_file_contains("${_tip_case}/runs/keep.txt" "existing user data")
if(_tip_expected_failure)
  if("${_tip_result}" STREQUAL "0")
    _tip_proof_fail("${TIP_CHECK_CASE} unexpectedly succeeded: ${_tip_case}/check.log")
  endif()
  foreach(_tip_expected IN LISTS _tip_expected_failure)
    _tip_proof_assert_file_contains("${_tip_case}/check.log" "${_tip_expected}")
  endforeach()
else()
  if(NOT "${_tip_result}" STREQUAL "0")
    _tip_proof_fail("${TIP_CHECK_CASE} failed:\n${_tip_stdout}\n${_tip_stderr}")
  endif()
  _tip_proof_assert_file_contains("${_tip_case}/check.log" "Installed and relocated consumer checks passed")
endif()

# The relocation regression must pass the first consumer before failing the second.
file(GLOB _tip_runs "${_tip_work_root}/consumer-check-*")
list(LENGTH _tip_runs _tip_run_count)
if(NOT _tip_run_count EQUAL 1)
  _tip_proof_fail("Expected exactly one check run, got ${_tip_run_count}")
endif()
if(TIP_CHECK_CASE STREQUAL "success"
   OR TIP_CHECK_CASE STREQUAL "broken-relocation"
   OR TIP_CHECK_CASE STREQUAL "bracket-values"
   OR TIP_CHECK_CASE MATCHES "^cross-")
  _tip_proof_assert_not_exists("${_tip_runs}/install")
  _tip_proof_assert_exists("${_tip_runs}/relocated/share/cmake/answer/answerConfig.cmake")
  _tip_proof_assert_exists("${_tip_runs}/installed-build.log")
endif()
if(TIP_CHECK_CASE STREQUAL "cross-build" OR TIP_CHECK_CASE STREQUAL "cross-rooted")
  _tip_proof_assert_file_contains("${_tip_case}/check.log" "runtime checks skipped (mode=AUTO, cross-compiling=TRUE)")
  _tip_proof_assert_not_exists("${_tip_runs}/installed-test.log")
  _tip_proof_assert_not_exists("${_tip_runs}/relocated-test.log")
elseif(
  TIP_CHECK_CASE STREQUAL "success"
  OR TIP_CHECK_CASE STREQUAL "cross-emulator"
  OR TIP_CHECK_CASE STREQUAL "bracket-values")
  _tip_proof_assert_file_contains("${_tip_runs}/installed-test.log" "100% tests passed")
  _tip_proof_assert_file_contains("${_tip_runs}/relocated-test.log" "100% tests passed")
endif()
if(TIP_CHECK_CASE STREQUAL "bracket-values")
  _tip_proof_assert_file_contains("${_tip_runs}/relocated-consumer/CMakeCache.txt" "CMAKE_PREFIX_PATH:STRING=${_tip_runs}/relocated;${_tip_case}/sdk]=]-]==]-]===]prefix")
endif()
