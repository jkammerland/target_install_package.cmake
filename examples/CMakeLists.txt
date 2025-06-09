cmake_minimum_required(VERSION 3.23)
project(examples-test VERSION 0.1.0)

include(CTest)
enable_testing()

add_test(
  NAME build_all_examples_test
  COMMAND sh ${CMAKE_CURRENT_SOURCE_DIR}/build_all_examples.sh
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

# Step 1: Collect all items in the examples directory
file(GLOB example_items "${CMAKE_CURRENT_SOURCE_DIR}/*")

# Step 2: Filter out only directories and exclude 'build'
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

# Step 3: Foreach directory, add CMAKE_PREFIX_PATH
foreach(example_dir IN LISTS EXAMPLE_DIRECTORIES)
  message(STATUS "Adding example path: ${CMAKE_CURRENT_SOURCE_DIR}/${example_dir}/build/install")
  list(APPEND CMAKE_PREFIX_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${example_dir}/build/install")
endforeach()
