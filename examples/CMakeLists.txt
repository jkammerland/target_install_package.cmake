cmake_minimum_required(VERSION 3.25)
project(examples-test VERSION 0.1.0)

message(NOTICE "Current CMAKE_VERSION: ${CMAKE_VERSION}")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_EXTENSIONS OFF)

# Dependencies needed for dependency-aggregation example.
#
# Default is FetchContent for CI parity, but allow opting out (e.g. offline local runs) and using pre-installed packages instead.
option(EXAMPLES_USE_FETCHCONTENT_DEPS "Fetch external deps via FetchContent (requires network)" ON)

if(EXAMPLES_USE_FETCHCONTENT_DEPS)
  include(FetchContent)

  # Use OVERRIDE_FIND_PACKAGE so any find_dependency() calls from installed packages will automatically redirect to FetchContent, ensuring seamless integration.
  FetchContent_Declare(
    fmt
    GIT_REPOSITORY https://github.com/fmtlib/fmt.git
    GIT_TAG 53d006abfdc0653f7d3e4e180e694fcb720524b5
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

  # Make dependencies available - find_package() calls will now use FetchContent automatically.
  FetchContent_MakeAvailable(fmt spdlog cxxopts)
else()
  find_package(fmt 11.1.4 CONFIG REQUIRED)
  find_package(spdlog 1.15.3 CONFIG REQUIRED)
  find_package(cxxopts 3.1.1 CONFIG REQUIRED)
endif()

option(RUN_BUILD_ALL_EXAMPLES "Run build shell script automatically" ON)
set(EXAMPLES_BUILD_ROOT
    ""
    CACHE PATH "Out-of-source build root for build_all_examples.sh (empty uses examples/*/build)")

if(RUN_BUILD_ALL_EXAMPLES)
  # ~~~
  # Step 1: Run the build script
  #
  message(STATUS "Running build script, this may take some time...")
  set(build_script "${CMAKE_CURRENT_SOURCE_DIR}/build_all_examples.sh")
  set(build_script_args)
  if(EXAMPLES_BUILD_ROOT)
    list(APPEND build_script_args --build-root "${EXAMPLES_BUILD_ROOT}")
  endif()
  if(WIN32)
    find_program(BASH_EXECUTABLE bash)
    if(NOT BASH_EXECUTABLE)
      message(FATAL_ERROR "RUN_BUILD_ALL_EXAMPLES requires bash on Windows to run ${build_script}")
    endif()
    set(build_command "${BASH_EXECUTABLE}" "${build_script}")
  else()
    set(build_command "${build_script}")
  endif()
  list(APPEND build_command ${build_script_args})
  execute_process(
    COMMAND ${build_command}
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    RESULT_VARIABLE build_result
    OUTPUT_VARIABLE build_output
    ERROR_VARIABLE build_error)

  # Step 2: Handle build result
  if(NOT build_result EQUAL 0)
    message(FATAL_ERROR "Failed to build examples (exit ${build_result}):\n" "--- stderr ---\n${build_error}\n" "--- stdout ---\n${build_output}\n")
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

# Step 5: For each example directory, add the single shared install prefix
foreach(example_dir IN LISTS EXAMPLE_DIRECTORIES)
  get_filename_component(dir_name ${example_dir} NAME)
  if(EXAMPLES_BUILD_ROOT)
    set(shared_prefix "${EXAMPLES_BUILD_ROOT}/${dir_name}/install")
  else()
    set(shared_prefix "${example_dir}/build/install")
  endif()
  message(VERBOSE "Adding example path: ${shared_prefix}")
  list(APPEND CMAKE_PREFIX_PATH "${shared_prefix}")
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

if(SHOULD_TEST_CXX_MODULES)
  add_executable(test_math_modules_consumer test_math_modules_consumer.cpp)
  target_link_libraries(test_math_modules_consumer PRIVATE MathModules::math_modules)
  set_target_properties(test_math_modules_consumer PROPERTIES CXX_EXTENSIONS OFF CXX_SCAN_FOR_MODULES ON)
  add_test(NAME examples_math_modules_consume_test COMMAND test_math_modules_consumer)
  set_tests_properties(examples_math_modules_consume_test PROPERTIES TIMEOUT 120 LABELS "integration;modules")
  message(STATUS "--- Module consumption test enabled for MathModules::math_modules ---")
endif()

# Add RPATH test to verify installed binaries can find their shared library dependencies
find_program(
  RPATH_DEMO_EXECUTABLE
  NAMES rpath_demo
  PATHS ${CMAKE_PREFIX_PATH}
  PATH_SUFFIXES bin release/bin relwithdebinfo/bin minsizerel/bin debug/bin
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
