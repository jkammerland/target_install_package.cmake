cmake_minimum_required(VERSION 3.25)

if(NOT DEFINED RPATH_EXAMPLE_BUILD_DIR)
  message(FATAL_ERROR "RPATH_EXAMPLE_BUILD_DIR is required")
endif()

if(NOT DEFINED RPATH_TEST_PREFIX)
  message(FATAL_ERROR "RPATH_TEST_PREFIX is required")
endif()

file(REMOVE_RECURSE "${RPATH_TEST_PREFIX}")

execute_process(
  COMMAND "${CMAKE_COMMAND}" --install "${RPATH_EXAMPLE_BUILD_DIR}" --prefix "${RPATH_TEST_PREFIX}" --config Release
  RESULT_VARIABLE install_result
  OUTPUT_VARIABLE install_output
  ERROR_VARIABLE install_error)

if(NOT install_result EQUAL 0)
  message(FATAL_ERROR "Failed to reinstall rpath-example to ${RPATH_TEST_PREFIX}:\n${install_output}\n${install_error}")
endif()

set(executable_candidates
    "${RPATH_TEST_PREFIX}/bin/rpath_demo"
    "${RPATH_TEST_PREFIX}/bin/rpath_demo.exe"
    "${RPATH_TEST_PREFIX}/release/bin/rpath_demo"
    "${RPATH_TEST_PREFIX}/release/bin/rpath_demo.exe"
    "${RPATH_TEST_PREFIX}/relwithdebinfo/bin/rpath_demo"
    "${RPATH_TEST_PREFIX}/relwithdebinfo/bin/rpath_demo.exe"
    "${RPATH_TEST_PREFIX}/minsizerel/bin/rpath_demo"
    "${RPATH_TEST_PREFIX}/minsizerel/bin/rpath_demo.exe"
    "${RPATH_TEST_PREFIX}/debug/bin/rpath_demo")
list(APPEND executable_candidates "${RPATH_TEST_PREFIX}/debug/bin/rpath_demo.exe")

set(rpath_demo_executable "")
foreach(candidate IN LISTS executable_candidates)
  if(EXISTS "${candidate}")
    set(rpath_demo_executable "${candidate}")
    break()
  endif()
endforeach()

if(NOT rpath_demo_executable)
  message(FATAL_ERROR "Could not find reinstalled rpath_demo under ${RPATH_TEST_PREFIX}")
endif()

execute_process(
  COMMAND "${rpath_demo_executable}"
  RESULT_VARIABLE run_result
  OUTPUT_VARIABLE run_output
  ERROR_VARIABLE run_error)

if(NOT run_result EQUAL 0)
  message(FATAL_ERROR "Reinstalled rpath_demo failed:\n${run_output}\n${run_error}")
endif()

string(FIND "${run_output}" "RPATH example completed successfully!" success_index)
if(success_index EQUAL -1)
  message(FATAL_ERROR "Unexpected rpath_demo output:\n${run_output}\n${run_error}")
endif()

if(UNIX AND NOT APPLE)
  find_program(READELF_EXECUTABLE readelf)
  if(READELF_EXECUTABLE)
    execute_process(
      COMMAND "${READELF_EXECUTABLE}" -d "${rpath_demo_executable}"
      RESULT_VARIABLE readelf_result
      OUTPUT_VARIABLE readelf_output
      ERROR_VARIABLE readelf_error)

    if(NOT readelf_result EQUAL 0)
      message(FATAL_ERROR "readelf failed for ${rpath_demo_executable}:\n${readelf_error}")
    endif()

    string(FIND "${readelf_output}" "$ORIGIN" origin_index)
    if(origin_index EQUAL -1)
      message(FATAL_ERROR "Expected ${rpath_demo_executable} RUNPATH/RPATH to contain $ORIGIN:\n${readelf_output}")
    endif()
  endif()
endif()
