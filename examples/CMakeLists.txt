cmake_minimum_required(VERSION 3.23)
project(examples-test VERSION 0.1.0)

message(NOTICE "Current CMAKE_VERSION: ${CMAKE_VERSION}")

# Fetch dependencies needed for dependency-aggregation example
include(FetchContent)

FetchContent_Declare(
  fmt
  GIT_REPOSITORY https://github.com/fmtlib/fmt.git
  GIT_TAG 10.0.0
  FIND_PACKAGE_ARGS NAMES fmt)

FetchContent_Declare(
  spdlog
  GIT_REPOSITORY https://github.com/gabime/spdlog.git
  GIT_TAG v1.12.0
  FIND_PACKAGE_ARGS NAMES spdlog)

FetchContent_Declare(
  cxxopts
  GIT_REPOSITORY https://github.com/jarro2783/cxxopts.git
  GIT_TAG v3.1.1
  FIND_PACKAGE_ARGS NAMES cxxopts)

FetchContent_MakeAvailable(fmt spdlog cxxopts)

option(RUN_BUILD_ALL_EXAMPLES "Run build shell script automatically" ON)

if(RUN_BUILD_ALL_EXAMPLES)
  # ~~~
  # Step 1: Run the build script
  #
  message(STATUS "Running build script, this may take some time...")
  execute_process(
    COMMAND ${CMAKE_COMMAND} -E chdir ${CMAKE_CURRENT_SOURCE_DIR} ./build_all_examples.sh
    RESULT_VARIABLE build_result
    OUTPUT_VARIABLE build_output
    ERROR_VARIABLE build_error)

  # Step 2: Handle build result
  if(NOT build_result EQUAL 0)
    message(FATAL_ERROR "Failed to build examples:\n${build_error}")
  else()
    message(STATUS "Examples built successfully:\n${build_output}")
  endif()
  # ~~~
else()
  message(NOTICE "Make sure to run build_all_examples.sh first!")
endif()

# Step 3: Collect all items in the examples directory
file(GLOB example_items "${CMAKE_CURRENT_SOURCE_DIR}/*")

# Step 4: Filter out only directories and exclude 'build'
set(EXAMPLE_DIRECTORIES "")
message(STATUS "Adding example directory:")
foreach(item IN LISTS example_items)
  if(IS_DIRECTORY ${item})
    # Get the directory name
    get_filename_component(dir_name ${item} NAME)

    # Skip 'build' directories at the top level
    if(NOT dir_name STREQUAL "build")
      message(STATUS "  ${dir_name}")
      list(APPEND EXAMPLE_DIRECTORIES ${item})
    endif()
  endif()
endforeach()

# Step 5: Foreach directory, add CMAKE_PREFIX_PATH
foreach(example_dir IN LISTS EXAMPLE_DIRECTORIES)
  message(VERBOSE "Adding example path: ${example_dir}/build/install")
  list(APPEND CMAKE_PREFIX_PATH "${example_dir}/build/install/")
endforeach()

# ~~~
# This logic *must mirror* the logic in cxx-modules/CMakeLists.txt
# It determines if we should find_package(math_modules).
# ~~~
set(SHOULD_TEST_CXX_MODULES FALSE)
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "14.0")
    set(SHOULD_TEST_CXX_MODULES TRUE)
  endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "19.0")
    set(SHOULD_TEST_CXX_MODULES TRUE)
  endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL "19.29")
    set(SHOULD_TEST_CXX_MODULES TRUE)
  endif()
endif()

# Step 6: Find all packages
find_package(algorithms CONFIG REQUIRED)
find_package(string_utils CONFIG REQUIRED)
find_package(math_lib CONFIG REQUIRED)
find_package(math_utils CONFIG REQUIRED)
find_package(media_core CONFIG REQUIRED)
find_package(media_dev_tools CONFIG REQUIRED)
find_package(asset_converter CONFIG REQUIRED)
find_package(config_lib CONFIG REQUIRED)
find_package(engine2 CONFIG REQUIRED)
find_package(mylib CONFIG REQUIRED)
find_package(cpack_lib CONFIG REQUIRED)
find_package(cbor_tags REQUIRED)
find_package(json_parser_v2 REQUIRED)
find_package(data_package REQUIRED)
find_package(libA CONFIG REQUIRED)
find_package(libB CONFIG REQUIRED)

# Conditionally find the modules package
if(SHOULD_TEST_CXX_MODULES AND CMAKE_VERSION VERSION_GREATER_EQUAL 3.28)
  message(STATUS "Compiler supports C++ Modules. Verifying find_package(math_modules)...")
  find_package(math_modules CONFIG REQUIRED)
else()
  message(WARNING "Compiler/CMake does not meet C++ Modules requirements. Skipping find_package(math_modules) check.")
endif()

message(STATUS "--- Verification Summary ---")
message(STATUS "Found package algorithms: ${algorithms_FOUND}")
message(STATUS "Found package string_utils: ${string_utils_FOUND}")
message(STATUS "Found package math_lib: ${math_lib_FOUND}")
message(STATUS "Found package math_utils: ${math_utils_FOUND}")
message(STATUS "Found package media_core: ${media_core_FOUND}")
message(STATUS "Found package media_dev_tools: ${media_dev_tools_FOUND}")
message(STATUS "Found package asset_converter: ${asset_converter_FOUND}")
message(STATUS "Found package config_lib: ${config_lib_FOUND}")
message(STATUS "Found package game_engine: ${game_engine_FOUND}")
message(STATUS "Found package engine2: ${engine2_FOUND}")
message(STATUS "Found package mylib(fmt, spdlog, cxxopts): ${mylib_FOUND}")
message(STATUS "Found package cpack_basic_example: ${cpack_lib_FOUND}")
message(STATUS "Found package cbor_tags: ${cbor_tags_FOUND}")
message(STATUS "Found package json_parser_v2: ${json_parser_v2_FOUND}")
message(STATUS "Found package data_package: ${data_package_FOUND}")
message(STATUS "Found package libA: ${libA_FOUND}")
message(STATUS "Found package libB: ${libB_FOUND}")
if(SHOULD_TEST_CXX_MODULES)
  message(STATUS "Found package math_modules: ${math_modules_FOUND}")
else()
  message(STATUS "Skipped package math_modules: OK")
endif()

message(STATUS "--- Testing linking a binary with the libraries ---")
add_executable(test_examples_main test_examples_main.cpp)
target_link_libraries(test_examples_main PRIVATE MyLib::core_lib cbor::tags json::parser data::core data::utils)
message(STATUS "--- Linking OK ---")
