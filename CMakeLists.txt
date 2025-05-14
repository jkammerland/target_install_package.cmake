cmake_minimum_required(VERSION 3.28) # 3.28 for CXX_MODULES

project(target_install_package VERSION 1.0.2)

# Get the project log package
set(PROJECT_LOG_VERSION "1.0.5")
get_property(
  CPM_INITIALIZED GLOBAL
  PROPERTY CPM_INITIALIZED
  SET)
if(CPM_INITIALIZED)
  cpmaddpackage("gh:jkammerland/project_log.cmake@${PROJECT_LOG_VERSION}")
else()
  include(FetchContent)
  FetchContent_Declare(
    project_log
    GIT_REPOSITORY https://github.com/jkammerland/project_log.cmake.git
    GIT_TAG v${PROJECT_LOG_VERSION} # or branch/commit
  )
  FetchContent_MakeAvailable(project_log)
endif()
project_include_guard() # Guard against multiple add_subdirectory

# Include the target install package function
include(${CMAKE_CURRENT_LIST_DIR}/target_configure_sources.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/target_install_package.cmake)

# TESTS - Include guard, this must be root dir
if(NOT ${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_CURRENT_LIST_DIR})
  return()
else()
  project_log(VERBOSE "Running standalone, including tests...")
  add_subdirectory(tests)
endif()
