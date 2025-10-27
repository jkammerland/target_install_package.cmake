cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED ENV{TIP_EXPECTED_PATH})
  message(FATAL_ERROR "TIP_EXPECTED_PATH not set")
endif()

set(_tip_path "$ENV{TIP_EXPECTED_PATH}")
file(TO_CMAKE_PATH "${_tip_path}" _tip_path)

if(NOT EXISTS "${_tip_path}")
  message(FATAL_ERROR "Expected path '${_tip_path}' to exist but it does not")
endif()
