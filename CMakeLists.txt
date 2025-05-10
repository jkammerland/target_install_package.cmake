cmake_minimum_required(VERSION 3.25)

project(target_install_package)

include(${CMAKE_CURRENT_LIST_DIR}/target_install_package.cmake)

include(FetchContent)

FetchContent_Declare(
  project_log
  GIT_REPOSITORY https://github.com/jkammerland/project_log.cmake.git
  GIT_TAG v1.0.0 # or branch/commit
)

FetchContent_MakeAvailable(project_log)

# Include guard, this must be root dir
if(NOT ${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_CURRENT_LIST_DIR})
  return()
else()
  project_log(VERBOSE "Running standalone, including tests...")
  add_subdirectory(tests)
endif()
