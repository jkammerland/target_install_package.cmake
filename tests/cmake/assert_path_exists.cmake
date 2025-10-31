cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED ENV{TIP_EXPECTED_PATH})
  message(FATAL_ERROR "assert_path_exists: TIP_EXPECTED_PATH environment variable is not set")
endif()

set(_tip_expected_path "$ENV{TIP_EXPECTED_PATH}")
if(NOT EXISTS "${_tip_expected_path}")
  message(FATAL_ERROR "assert_path_exists: Expected path not found: ${_tip_expected_path}")
endif()

message(STATUS "assert_path_exists: Found ${_tip_expected_path}")
