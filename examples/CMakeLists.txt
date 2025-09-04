cmake_minimum_required(VERSION 3.23)
project(examples-test VERSION 0.1.0)

message(NOTICE "Current CMAKE_VERSION: ${CMAKE_VERSION}")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_EXTENSIONS OFF)

# Fetch dependencies needed for dependency-aggregation example
include(FetchContent)

# Use OVERRIDE_FIND_PACKAGE so any find_dependency() calls from installed packages will automatically redirect to FetchContent, ensuring seamless integration
FetchContent_Declare(
  fmt
  GIT_REPOSITORY https://github.com/fmtlib/fmt.git
  GIT_TAG 11.1.4
  OVERRIDE_FIND_PACKAGE)

FetchContent_Declare(
  spdlog
  GIT_REPOSITORY https://github.com/gabime/spdlog.git
  GIT_TAG v1.15.3
  OVERRIDE_FIND_PACKAGE)

FetchContent_Declare(
  cxxopts
  GIT_REPOSITORY https://github.com/jarro2783/cxxopts.git
  GIT_TAG v3.1.1
  OVERRIDE_FIND_PACKAGE)

# On macOS, completely avoid building fmt static library to prevent malloc/free errors
if(APPLE)
  # Populate fmt source without building
  FetchContent_Populate(fmt)
  
  # Create header-only interface target manually
  add_library(fmt_header_only INTERFACE)
  target_include_directories(fmt_header_only INTERFACE ${fmt_SOURCE_DIR}/include)
  target_compile_definitions(fmt_header_only INTERFACE FMT_HEADER_ONLY=1)
  add_library(fmt::fmt ALIAS fmt_header_only)
  add_library(fmt::fmt-header-only ALIAS fmt_header_only)
  
  # Now make available spdlog and cxxopts normally
  FetchContent_MakeAvailable(spdlog cxxopts)
else()
  # On other platforms, use normal FetchContent
  FetchContent_MakeAvailable(fmt spdlog cxxopts)
endif()

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

# Check C++ modules support using centralized function
include(${CMAKE_CURRENT_SOURCE_DIR}/check_cxx_modules_support.cmake)
check_cxx_modules_support(SHOULD_TEST_CXX_MODULES)

# Step 6: Find all packages
find_package(algorithms CONFIG REQUIRED)
find_package(string_utils CONFIG REQUIRED)
find_package(math_lib CONFIG REQUIRED)
find_package(math_utils CONFIG REQUIRED)
find_package(MediaLib CONFIG REQUIRED)
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
if(SHOULD_TEST_CXX_MODULES)
  find_package(math_modules CONFIG REQUIRED)
  find_package(math_partitions CONFIG REQUIRED)
endif()

message(STATUS "--- Verification Summary ---")
message(STATUS "Found package algorithms: ${algorithms_FOUND}")
message(STATUS "Found package string_utils: ${string_utils_FOUND}")
message(STATUS "Found package math_lib: ${math_lib_FOUND}")
message(STATUS "Found package math_utils: ${math_utils_FOUND}")
message(STATUS "Found package MediaLib: ${MediaLib_FOUND}")
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
  message(STATUS "Found package math_partitions: ${math_partitions_FOUND}")
else()
  message(STATUS "Skipped package math_modules: OK")
  message(STATUS "Skipped package math_partitions: OK")
endif()

message(STATUS "--- Testing linking a binary with the libraries ---")
add_executable(test_examples_main test_examples_main.cpp)
target_link_libraries(test_examples_main PRIVATE MyLib::core_lib cbor::tags json::parser data::core data::utils)

# Add conditional module linking and compile definitions
if(SHOULD_TEST_CXX_MODULES)
  target_link_libraries(test_examples_main PRIVATE MathPartitions::math_partitions)
  target_compile_definitions(test_examples_main PRIVATE HAVE_MATH_PARTITIONS=1 MODULES_AVAILABLE=1)
  target_compile_features(test_examples_main PRIVATE cxx_std_20)
  # Ensure consistent compiler flags with module libraries (no GNU extensions)
  set_target_properties(test_examples_main PROPERTIES CXX_EXTENSIONS OFF CXX_SCAN_FOR_MODULES ON)
  message(STATUS "--- Module linking enabled for test_examples_main ---")
endif()

# ~~~
# Windows: No RPATH mechanism exists - DLLs must be co-located with executables or in PATH
# Since we installed deps t custom locations, copy DLLs to executable directory
# ~~~
if(WIN32)
  add_custom_command(
    TARGET test_examples_main
    POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy -t $<TARGET_FILE_DIR:test_examples_main> $<TARGET_RUNTIME_DLLS:test_examples_main>
    COMMAND_EXPAND_LISTS)
endif()

# Enable testing and add the integration test
enable_testing()
add_test(NAME examples_integration_test COMMAND test_examples_main)
set_tests_properties(examples_integration_test PROPERTIES TIMEOUT 300 # 5 minute timeout
                                                          LABELS "integration")

# Add RPATH test to verify installed binaries can find their shared library dependencies
find_program(
  RPATH_DEMO_EXECUTABLE
  NAMES rpath_demo
  PATHS ${CMAKE_PREFIX_PATH}
  PATH_SUFFIXES bin
  NO_DEFAULT_PATH)

if(RPATH_DEMO_EXECUTABLE)
  add_test(NAME rpath_functionality_test COMMAND ${RPATH_DEMO_EXECUTABLE})
  set_tests_properties(rpath_functionality_test PROPERTIES TIMEOUT 30 LABELS "rpath;integration" PASS_REGULAR_EXPRESSION "RPATH example completed successfully!")
  message(STATUS "--- RPATH test configured with executable: ${RPATH_DEMO_EXECUTABLE} ---")
else()
  message(FATAL_ERROR "rpath_demo executable not found - RPATH test will be skipped")
endif()

message(STATUS "--- Linking OK ---")
message(STATUS "--- Integration test configured ---")
